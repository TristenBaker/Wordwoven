extends RefCounted
## Explicit preparation vocabulary. Each word belongs to exactly one fate.
## Keep single-word adjective headwords; run fate_classifier_test after edits.
## List the clearest example first: the preparation screen uses it as a hint.
const WORDS: Dictionary = {
	"titanbound": [
		"strong", "tough", "durable", "massive", "robust", "sturdy", "hardy",
		"muscular", "mighty", "powerful", "brawny", "burly", "hulking",
		"colossal", "gigantic", "enormous", "immense", "stout", "rugged",
		"stalwart", "resilient", "vigorous", "herculean", "titanic",
		"indestructible",
	],
	"doommarked": [
		"weak", "frail", "brittle", "sickly", "feeble", "fragile",
		"delicate", "infirm", "puny", "flimsy", "decrepit", "debilitated",
		"weakened", "unhealthy", "ailing", "emaciated", "scrawny", "wasted",
		"withered", "breakable", "perishable",
	],
	"war_blessed": [
		"angry", "violent", "ferocious", "hostile", "cruel", "irate",
		"vicious", "aggressive", "belligerent", "bellicose", "combative",
		"bloodthirsty", "brutal", "feral", "fierce", "furious", "murderous",
		"merciless", "ruthless", "savage", "wrathful", "enraged", "warlike",
		"pugnacious", "truculent",
	],
	"spirit_broken": [
		"timid", "fearful", "cowardly", "meek", "afraid", "frightened",
		"scared", "terrified", "apprehensive", "anxious", "nervous",
		"tremulous", "timorous", "intimidated", "panicky", "spineless",
		"fainthearted", "pusillanimous", "craven", "diffident", "hesitant",
		"submissive",
	],
	"fate_exposed": [
		"vulnerable", "exposed", "defenseless", "defenceless", "unprotected",
		"unguarded", "unarmored", "unarmoured", "unshielded", "unwary",
		"unsuspecting", "unaware", "oblivious", "inattentive", "careless",
		"incautious", "unprepared", "open", "naked", "bare", "uncovered",
	],
	"spellwarden": [
		"protected", "guarded", "armored", "armoured", "shielded",
		"fortified", "sheltered", "covered", "enclosed", "encased",
		"reinforced", "impregnable", "impenetrable", "impervious",
		"invulnerable", "resistant", "defensive", "ironclad", "secure",
		"inviolable", "imperviable", "unassailable", "unbreakable",
		"adamantine",
	],
	"drowsy": [
		"drowsy", "sleepy", "somnolent", "slumberous", "slumbrous", "asleep",
		"sleeping", "dozy", "lethargic", "sluggish", "torpid", "soporific",
		"dormant", "tired", "weary", "exhausted", "fatigued", "languid",
		"listless", "groggy", "comatose", "narcoleptic",
	],
	"clumsy": [
		"clumsy", "awkward", "uncoordinated", "bumbling", "bungling",
		"maladroit", "inept", "ungainly", "graceless", "lumbering",
		"fumbling", "gawky", "butterfingered", "unskillful", "inexpert",
		"ungraceful", "oafish", "unsteady", "sloppy", "incompetent",
		"unwieldy",
	],
	"long_winded": [
		"verbose", "wordy", "prolix", "loquacious", "talkative", "garrulous",
		"chatty", "voluble", "rambling", "circumlocutory", "circumlocutious",
		"discursive", "digressive", "repetitive", "redundant",
		"tautological", "pleonastic", "periphrastic", "gabby", "blabby",
		"talky",
	],
	"echo_bound": [
		"resonant", "echoing", "reverberant", "resounding", "reverberating",
		"sonorous", "booming", "thunderous", "thundering", "rumbling",
		"vibratory", "hollow", "acoustic", "acoustical", "echoic",
		"reverberative", "resonating", "sonant", "cavernous", "clangorous",
	],
	"chameleon": [
		"fickle", "changeable", "mercurial", "mutable", "variable",
		"inconstant", "capricious", "unpredictable", "erratic", "unstable",
		"shifting", "changing", "protean", "kaleidoscopic", "versatile",
		"adaptable", "fluid", "fluctuating", "volatile", "inconsistent",
		"vacillating", "wavering", "transformable",
	],
	"greedy": [
		"greedy", "avaricious", "covetous", "acquisitive", "grasping",
		"rapacious", "voracious", "insatiable", "unquenchable", "gluttonous",
		"ravenous", "hoggish", "piggish", "miserly", "stingy",
		"parsimonious", "mercenary", "venal", "possessive",
		"selfish",
	],
	"frostbite_tax": [
		"frigid", "wintry", "icy", "cold", "frosty", "frozen", "glacial",
		"arctic", "polar", "gelid", "chilly", "icebound", "snowbound",
		"snowy", "wintery", "hibernal", "numbing",
		"nippy", "shivery", "algid", "rimy", "subarctic", "antarctic",
	],
}
