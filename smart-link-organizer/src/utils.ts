// Minimal French/English stopword list, used to strip low-signal words
// before comparing note content for similarity.
const STOPWORDS = new Set([
	// French
	"les", "des", "une", "dans", "pour", "avec", "sur", "que", "qui", "est",
	"été", "être", "cette", "comme", "plus", "tout", "tous", "toute", "toutes",
	"mais", "sans", "sous", "entre", "vers", "chez", "alors", "donc", "aussi",
	"très", "peut", "fait", "ces", "son", "ses", "leur", "leurs", "nous",
	"vous", "ils", "elle", "elles", "on", "ce", "cet", "cette", "au", "aux",
	"du", "de", "la", "le", "un", "et", "ou", "en", "à", "par", "afin",
	// English
	"the", "and", "for", "with", "that", "this", "from", "have", "has", "are",
	"was", "were", "been", "not", "but", "you", "your", "they", "their",
	"its", "it", "of", "in", "on", "at", "to", "a", "an", "is", "be", "as", "by",
]);

/** Lowercase, strip accents/diacritics, split into significant words (>=4 chars, not a stopword). */
export function tokenize(text: string): Set<string> {
	const normalized = text
		.toLowerCase()
		.normalize("NFD")
		.replace(/[̀-ͯ]/g, "");
	const words = normalized.match(/[a-z0-9]{4,}/g) ?? [];
	return new Set(words.filter((w) => !STOPWORDS.has(w)));
}

/** Jaccard similarity (intersection / union) between two token sets, in [0, 1]. */
export function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
	if (a.size === 0 || b.size === 0) return 0;
	let intersection = 0;
	for (const w of a) {
		if (b.has(w)) intersection++;
	}
	const union = a.size + b.size - intersection;
	return union === 0 ? 0 : intersection / union;
}

/** Standard Levenshtein edit distance between two strings. */
export function levenshtein(a: string, b: string): number {
	const m = a.length;
	const n = b.length;
	if (m === 0) return n;
	if (n === 0) return m;

	let previousRow = new Array(n + 1);
	let currentRow = new Array(n + 1);
	for (let j = 0; j <= n; j++) previousRow[j] = j;

	for (let i = 1; i <= m; i++) {
		currentRow[0] = i;
		for (let j = 1; j <= n; j++) {
			const cost = a[i - 1] === b[j - 1] ? 0 : 1;
			currentRow[j] = Math.min(
				currentRow[j - 1] + 1,
				previousRow[j] + 1,
				previousRow[j - 1] + cost
			);
		}
		[previousRow, currentRow] = [currentRow, previousRow];
	}
	return previousRow[n];
}

/** Title closeness in [0, 1], where 1 means identical titles. */
export function titleSimilarity(a: string, b: string): number {
	const maxLen = Math.max(a.length, b.length);
	if (maxLen === 0) return 1;
	const dist = levenshtein(a.toLowerCase(), b.toLowerCase());
	return 1 - dist / maxLen;
}

/** Returns true if `path` is inside one of the given ignored folders. */
export function isIgnoredPath(path: string, ignoredFolders: string[]): boolean {
	return ignoredFolders.some(
		(folder) => folder.length > 0 && (path === folder || path.startsWith(folder + "/"))
	);
}

/** Parses the comma-separated ignored-folders setting into a clean array. */
export function parseIgnoredFolders(raw: string): string[] {
	return raw
		.split(",")
		.map((f) => f.trim().replace(/^\/+|\/+$/g, ""))
		.filter((f) => f.length > 0);
}

/** Escapes a string for safe use inside a RegExp. */
export function escapeRegExp(text: string): string {
	return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
