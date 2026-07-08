import { App, Modal, TFile } from "obsidian";

export interface BrokenLinkItem {
	sourcePath: string;
	linkText: string;
	count: number;
}

export class BrokenLinksModal extends Modal {
	constructor(
		app: App,
		private links: BrokenLinkItem[],
		private onCreate: (linkText: string) => Promise<void>
	) {
		super(app);
	}

	onOpen(): void {
		const { contentEl } = this;
		contentEl.createEl("h2", { text: "Liens cassés" });

		if (this.links.length === 0) {
			contentEl.createEl("p", {
				text: "Aucun lien cassé trouvé. Ton vault est propre !",
				cls: "smart-organizer-empty",
			});
			return;
		}

		contentEl.createEl("p", {
			text: `${this.links.length} lien(s) pointent vers des notes inexistantes.`,
		});

		const list = contentEl.createDiv({ cls: "smart-organizer-list" });
		for (const item of this.links) {
			const row = list.createDiv({ cls: "smart-organizer-row" });
			row.createDiv({
				cls: "smart-organizer-row-text",
				text: `[[${item.linkText}]]  —  depuis « ${item.sourcePath} » (×${item.count})`,
			});
			const actions = row.createDiv({ cls: "smart-organizer-row-actions" });
			const btn = actions.createEl("button", { text: "Créer la note" });
			btn.onclick = async () => {
				btn.disabled = true;
				try {
					await this.onCreate(item.linkText);
					btn.setText("Créée ✓");
				} catch (e) {
					btn.setText("Échec");
					btn.disabled = false;
					console.error(e);
				}
			};
		}
	}

	onClose(): void {
		this.contentEl.empty();
	}
}

export interface SimilarNotePair {
	a: TFile;
	b: TFile;
	contentScore: number;
	titleScore: number;
}

export class SimilarNotesModal extends Modal {
	constructor(
		app: App,
		private pairs: SimilarNotePair[],
		private onOpenFile: (file: TFile) => void
	) {
		super(app);
	}

	onOpen(): void {
		const { contentEl } = this;
		contentEl.createEl("h2", { text: "Notes similaires / doublons potentiels" });

		if (this.pairs.length === 0) {
			contentEl.createEl("p", {
				text: "Aucune note similaire détectée avec les seuils actuels.",
				cls: "smart-organizer-empty",
			});
			return;
		}

		contentEl.createEl("p", {
			text: `${this.pairs.length} paire(s) de notes se ressemblent.`,
		});

		const list = contentEl.createDiv({ cls: "smart-organizer-list" });
		for (const pair of this.pairs) {
			const row = list.createDiv({ cls: "smart-organizer-row" });
			const textEl = row.createDiv({ cls: "smart-organizer-row-text" });
			textEl.createEl("div", { text: `${pair.a.basename}  ↔  ${pair.b.basename}` });
			textEl.createEl("div", {
				cls: "smart-organizer-score",
				text: `contenu : ${Math.round(pair.contentScore * 100)}%  ·  titre : ${Math.round(
					pair.titleScore * 100
				)}%`,
			});
			const actions = row.createDiv({ cls: "smart-organizer-row-actions" });
			const btnA = actions.createEl("button", { text: "Ouvrir A" });
			btnA.onclick = () => this.onOpenFile(pair.a);
			const btnB = actions.createEl("button", { text: "Ouvrir B" });
			btnB.onclick = () => this.onOpenFile(pair.b);
		}
	}

	onClose(): void {
		this.contentEl.empty();
	}
}

export interface LinkSuggestion {
	file: TFile;
	occurrences: number;
}

export class SuggestLinksModal extends Modal {
	constructor(
		app: App,
		private suggestions: LinkSuggestion[],
		private onInsert: (suggestion: LinkSuggestion) => void
	) {
		super(app);
	}

	onOpen(): void {
		const { contentEl } = this;
		contentEl.createEl("h2", { text: "Suggestions de liens" });

		if (this.suggestions.length === 0) {
			contentEl.createEl("p", {
				text: "Aucune mention non liée d'autres notes trouvée dans cette note.",
				cls: "smart-organizer-empty",
			});
			return;
		}

		contentEl.createEl("p", {
			text: "Ces titres de notes apparaissent en texte brut dans la note active. Clique pour transformer la première occurrence en lien.",
		});

		const list = contentEl.createDiv({ cls: "smart-organizer-list" });
		for (const suggestion of this.suggestions) {
			const row = list.createDiv({ cls: "smart-organizer-row" });
			row.createDiv({
				cls: "smart-organizer-row-text",
				text: `${suggestion.file.basename}  (×${suggestion.occurrences})`,
			});
			const actions = row.createDiv({ cls: "smart-organizer-row-actions" });
			const btn = actions.createEl("button", { text: "Lier" });
			btn.onclick = () => {
				this.onInsert(suggestion);
				btn.setText("Lié ✓");
				btn.disabled = true;
			};
		}
	}

	onClose(): void {
		this.contentEl.empty();
	}
}
