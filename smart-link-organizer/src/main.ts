import { MarkdownView, Notice, Plugin, TFile, normalizePath } from "obsidian";
import { DEFAULT_SETTINGS, SmartOrganizerSettingTab, SmartOrganizerSettings } from "./settings";
import {
	BrokenLinkItem,
	BrokenLinksModal,
	LinkSuggestion,
	SimilarNotePair,
	SimilarNotesModal,
	SuggestLinksModal,
} from "./modals";
import { escapeRegExp, isIgnoredPath, jaccardSimilarity, parseIgnoredFolders, tokenize, titleSimilarity } from "./utils";

export default class SmartLinkOrganizerPlugin extends Plugin {
	settings!: SmartOrganizerSettings;

	async onload(): Promise<void> {
		await this.loadSettings();

		this.addRibbonIcon("link", "Smart Link Organizer", () => {
			this.showBrokenLinks();
		});

		this.addCommand({
			id: "smart-organizer-find-broken-links",
			name: "Trouver les liens cassés",
			callback: () => this.showBrokenLinks(),
		});

		this.addCommand({
			id: "smart-organizer-find-similar-notes",
			name: "Trouver les notes similaires / doublons",
			callback: () => this.showSimilarNotes(),
		});

		this.addCommand({
			id: "smart-organizer-suggest-links",
			name: "Suggérer des liens pour la note active",
			editorCallback: (editor, view) => {
				if (view instanceof MarkdownView && view.file) {
					this.showLinkSuggestions(view);
				}
			},
		});

		this.addSettingTab(new SmartOrganizerSettingTab(this.app, this));
	}

	async loadSettings(): Promise<void> {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings(): Promise<void> {
		await this.saveData(this.settings);
	}

	private getIgnoredFolders(): string[] {
		return parseIgnoredFolders(this.settings.ignoredFolders);
	}

	// --- Broken links -----------------------------------------------------

	private showBrokenLinks(): void {
		const ignored = this.getIgnoredFolders();
		const unresolved = this.app.metadataCache.unresolvedLinks;
		const items: BrokenLinkItem[] = [];

		for (const [sourcePath, links] of Object.entries(unresolved)) {
			if (isIgnoredPath(sourcePath, ignored)) continue;
			for (const [linkText, count] of Object.entries(links)) {
				if (count <= 0) continue;
				items.push({ sourcePath, linkText, count });
			}
		}

		items.sort((a, b) => a.sourcePath.localeCompare(b.sourcePath) || a.linkText.localeCompare(b.linkText));

		new BrokenLinksModal(this.app, items, (linkText) => this.createMissingNote(linkText)).open();
	}

	private async createMissingNote(linkText: string): Promise<void> {
		const cleanName = linkText.split(/[#^]/)[0].trim();
		if (!cleanName) return;

		const fileName = cleanName.endsWith(".md") ? cleanName : `${cleanName}.md`;
		const path = normalizePath(fileName);

		if (this.app.vault.getAbstractFileByPath(path)) {
			new Notice(`« ${cleanName} » existe déjà.`);
			return;
		}

		const slashIndex = path.lastIndexOf("/");
		if (slashIndex !== -1) {
			const folderPath = path.substring(0, slashIndex);
			if (!this.app.vault.getAbstractFileByPath(folderPath)) {
				await this.app.vault.createFolder(folderPath).catch(() => {
					/* folder may already exist due to a race, ignore */
				});
			}
		}

		await this.app.vault.create(path, "");
		new Notice(`Note créée : ${cleanName}`);
	}

	// --- Similar / duplicate notes -----------------------------------------

	private async showSimilarNotes(): Promise<void> {
		const ignored = this.getIgnoredFolders();
		const files = this.app.vault.getMarkdownFiles().filter((f) => !isIgnoredPath(f.path, ignored));

		if (files.length > this.settings.maxNotesForSimilarityScan) {
			new Notice(
				`Le vault contient ${files.length} notes, au-delà de la limite de sécurité (${this.settings.maxNotesForSimilarityScan}). Augmente la limite dans les réglages si besoin.`
			);
			return;
		}

		new Notice("Analyse des notes en cours…");

		const tokenSets = new Map<string, Set<string>>();
		for (const file of files) {
			const content = await this.app.vault.cachedRead(file);
			tokenSets.set(file.path, tokenize(content));
		}

		const pairs: SimilarNotePair[] = [];
		for (let i = 0; i < files.length; i++) {
			for (let j = i + 1; j < files.length; j++) {
				const a = files[i];
				const b = files[j];
				const contentScore = jaccardSimilarity(tokenSets.get(a.path)!, tokenSets.get(b.path)!);
				const titleScore = titleSimilarity(a.basename, b.basename);
				if (
					contentScore >= this.settings.similarityThreshold ||
					titleScore >= this.settings.titleSimilarityThreshold
				) {
					pairs.push({ a, b, contentScore, titleScore });
				}
			}
		}

		pairs.sort((x, y) => Math.max(y.contentScore, y.titleScore) - Math.max(x.contentScore, x.titleScore));

		new SimilarNotesModal(this.app, pairs, (file) => this.openFile(file)).open();
	}

	private async openFile(file: TFile): Promise<void> {
		const leaf = this.app.workspace.getLeaf(false);
		await leaf.openFile(file);
	}

	// --- Suggest links for the active note ---------------------------------

	private showLinkSuggestions(view: MarkdownView): void {
		const file = view.file;
		if (!file) return;

		const ignored = this.getIgnoredFolders();
		const content = view.editor.getValue();
		const cache = this.app.metadataCache.getFileCache(file);

		const alreadyLinkedPaths = new Set<string>();
		if (cache?.links) {
			for (const link of cache.links) {
				const dest = this.app.metadataCache.getFirstLinkpathDest(link.link, file.path);
				if (dest) alreadyLinkedPaths.add(dest.path);
			}
		}

		const candidates = this.app.vault
			.getMarkdownFiles()
			.filter(
				(f) =>
					f.path !== file.path &&
					!isIgnoredPath(f.path, ignored) &&
					!alreadyLinkedPaths.has(f.path) &&
					f.basename.length >= this.settings.minLinkSuggestionLength
			);

		const suggestions: LinkSuggestion[] = [];
		for (const candidate of candidates) {
			const regex = new RegExp(`\\b${escapeRegExp(candidate.basename)}\\b`, "gi");
			const matches = content.match(regex);
			if (matches && matches.length > 0) {
				suggestions.push({ file: candidate, occurrences: matches.length });
			}
		}

		suggestions.sort((a, b) => b.occurrences - a.occurrences);

		new SuggestLinksModal(this.app, suggestions, (suggestion) =>
			this.insertLinkForSuggestion(view, suggestion)
		).open();
	}

	private insertLinkForSuggestion(view: MarkdownView, suggestion: LinkSuggestion): void {
		const editor = view.editor;
		const content = editor.getValue();
		const regex = new RegExp(`\\b${escapeRegExp(suggestion.file.basename)}\\b`, "i");
		const match = regex.exec(content);
		if (!match) {
			new Notice("Occurrence introuvable (le texte a peut-être changé).");
			return;
		}

		const from = editor.offsetToPos(match.index);
		const to = editor.offsetToPos(match.index + match[0].length);
		editor.replaceRange(`[[${match[0]}]]`, from, to);
		new Notice(`Lien inséré vers « ${suggestion.file.basename} ».`);
	}
}
