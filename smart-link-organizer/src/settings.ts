import { App, PluginSettingTab, Setting } from "obsidian";
import type SmartLinkOrganizerPlugin from "./main";

export interface SmartOrganizerSettings {
	/** Jaccard content-similarity threshold (0-1) above which two notes are flagged as "similar". */
	similarityThreshold: number;
	/** Title-closeness threshold (0-1) above which two notes are flagged as likely duplicates by name. */
	titleSimilarityThreshold: number;
	/** Comma-separated list of folder paths to exclude from all scans. */
	ignoredFolders: string;
	/** Minimum length (in characters) a note title must have to be suggested as a link. */
	minLinkSuggestionLength: number;
	/** Safety cap on vault size for the O(n^2) similarity scan. */
	maxNotesForSimilarityScan: number;
}

export const DEFAULT_SETTINGS: SmartOrganizerSettings = {
	similarityThreshold: 0.35,
	titleSimilarityThreshold: 0.82,
	ignoredFolders: "",
	minLinkSuggestionLength: 4,
	maxNotesForSimilarityScan: 1500,
};

export class SmartOrganizerSettingTab extends PluginSettingTab {
	plugin: SmartLinkOrganizerPlugin;

	constructor(app: App, plugin: SmartLinkOrganizerPlugin) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display(): void {
		const { containerEl } = this;
		containerEl.empty();

		containerEl.createEl("h2", { text: "Smart Link Organizer" });

		new Setting(containerEl)
			.setName("Seuil de similarité de contenu")
			.setDesc(
				"Entre 0 et 1. Plus la valeur est basse, plus le plugin signale des notes comme « similaires » facilement."
			)
			.addSlider((slider) =>
				slider
					.setLimits(0.1, 0.9, 0.05)
					.setValue(this.plugin.settings.similarityThreshold)
					.setDynamicTooltip()
					.onChange(async (value) => {
						this.plugin.settings.similarityThreshold = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Seuil de similarité de titre")
			.setDesc(
				"Entre 0 et 1. Utilisé pour repérer les notes dont le titre est presque identique (fautes de frappe, doublons)."
			)
			.addSlider((slider) =>
				slider
					.setLimits(0.5, 0.99, 0.01)
					.setValue(this.plugin.settings.titleSimilarityThreshold)
					.setDynamicTooltip()
					.onChange(async (value) => {
						this.plugin.settings.titleSimilarityThreshold = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Dossiers ignorés")
			.setDesc("Chemins de dossiers à exclure de tous les scans, séparés par des virgules (ex : Templates, Archives).")
			.addText((text) =>
				text
					.setPlaceholder("Templates, Archives")
					.setValue(this.plugin.settings.ignoredFolders)
					.onChange(async (value) => {
						this.plugin.settings.ignoredFolders = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Longueur minimale des titres suggérés")
			.setDesc("Les titres de notes plus courts que cette valeur ne seront pas proposés comme liens (évite le bruit).")
			.addSlider((slider) =>
				slider
					.setLimits(2, 10, 1)
					.setValue(this.plugin.settings.minLinkSuggestionLength)
					.setDynamicTooltip()
					.onChange(async (value) => {
						this.plugin.settings.minLinkSuggestionLength = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Limite de sécurité pour le scan de similarité")
			.setDesc(
				"Le scan de notes similaires compare chaque paire de notes. Au-delà de cette taille de vault, le scan est bloqué pour éviter de figer Obsidian."
			)
			.addText((text) =>
				text
					.setPlaceholder("1500")
					.setValue(String(this.plugin.settings.maxNotesForSimilarityScan))
					.onChange(async (value) => {
						const parsed = parseInt(value, 10);
						if (!Number.isNaN(parsed) && parsed > 0) {
							this.plugin.settings.maxNotesForSimilarityScan = parsed;
							await this.plugin.saveSettings();
						}
					})
			);
	}
}
