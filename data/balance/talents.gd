extends RefCounted
## Authoritative talent definitions and numerical tuning. Each node costs one point.
const NODES: Dictionary = {
  "fire_0": {
    "element": "fire",
    "name": "Fire Attunement",
    "description": "+5% fire damage.",
    "effects": {
      "fire_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "fire_1": {
    "element": "fire",
    "name": "Focused Power",
    "description": "+6% fire damage.",
    "effects": {
      "fire_damage_multiplier": 0.06
    },
    "requires": [
      "fire_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "fire_2": {
    "element": "fire",
    "name": "Kindling",
    "description": "Fire damage applies burn equal to 8% of its damage.",
    "effects": {
      "fire_burn_ratio": 0.08
    },
    "requires": [
      "fire_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "fire_3": {
    "element": "fire",
    "name": "Elemental Force",
    "description": "+8% fire damage.",
    "effects": {
      "fire_damage_multiplier": 0.08
    },
    "requires": [
      "fire_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "fire_4": {
    "element": "fire",
    "name": "Feed the Flame",
    "description": "Add 7% of Fire damage as burn.",
    "effects": {
      "fire_burn_ratio": 0.07
    },
    "requires": [
      "fire_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "fire_5": {
    "element": "fire",
    "name": "Greater Mastery",
    "description": "+10% fire damage.",
    "effects": {
      "fire_damage_multiplier": 0.1
    },
    "requires": [
      "fire_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "fire_6": {
    "element": "fire",
    "name": "Wildfire",
    "description": "Add 10% of Fire damage as burn.",
    "effects": {
      "fire_burn_ratio": 0.1
    },
    "requires": [
      "fire_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "fire_7": {
    "element": "fire",
    "name": "Inferno",
    "description": "+12% fire damage. Add 15% of Fire damage as burn.",
    "effects": {
      "fire_damage_multiplier": 0.12,
      "fire_burn_ratio": 0.15
    },
    "requires": [
      "fire_5",
      "fire_6"
    ],
    "tier": 4,
    "lane": 0
  },
  "lightning_0": {
    "element": "lightning",
    "name": "Lightning Attunement",
    "description": "+5% lightning damage.",
    "effects": {
      "lightning_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "lightning_1": {
    "element": "lightning",
    "name": "Focused Power",
    "description": "+6% lightning damage.",
    "effects": {
      "lightning_damage_multiplier": 0.06
    },
    "requires": [
      "lightning_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "lightning_2": {
    "element": "lightning",
    "name": "First Spark",
    "description": "Lightning gains an 8% chance to echo; echoes can repeat. Base echo damage is 30%.",
    "effects": {
      "lightning_echo_chance": 0.08,
      "lightning_echo_damage": 0.3
    },
    "requires": [
      "lightning_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "lightning_3": {
    "element": "lightning",
    "name": "Elemental Force",
    "description": "+8% lightning damage.",
    "effects": {
      "lightning_damage_multiplier": 0.08
    },
    "requires": [
      "lightning_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "lightning_4": {
    "element": "lightning",
    "name": "Charged Echo",
    "description": "Echoes deal an additional 20% of Lightning damage.",
    "effects": {
      "lightning_echo_damage": 0.2
    },
    "requires": [
      "lightning_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "lightning_5": {
    "element": "lightning",
    "name": "Greater Mastery",
    "description": "+10% lightning damage.",
    "effects": {
      "lightning_damage_multiplier": 0.1
    },
    "requires": [
      "lightning_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "lightning_6": {
    "element": "lightning",
    "name": "Chain Reaction",
    "description": "Add 8 percentage points to echo chance.",
    "effects": {
      "lightning_echo_chance": 0.08
    },
    "requires": [
      "lightning_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "lightning_7": {
    "element": "lightning",
    "name": "Stormheart",
    "description": "+12% lightning damage. Add 12 percentage points to echo chance.",
    "effects": {
      "lightning_damage_multiplier": 0.12,
      "lightning_echo_chance": 0.12
    },
    "requires": [
      "lightning_5",
      "lightning_6"
    ],
    "tier": 4,
    "lane": 0
  },
  "water_0": {
    "element": "water",
    "name": "Water Attunement",
    "description": "+5% water damage.",
    "effects": {
      "water_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "water_1": {
    "element": "water",
    "name": "Focused Power",
    "description": "+6% water damage.",
    "effects": {
      "water_damage_multiplier": 0.06
    },
    "requires": [
      "water_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "water_2": {
    "element": "water",
    "name": "Restoring Tide",
    "description": "Heal for 4% of Water damage.",
    "effects": {
      "water_heal_ratio": 0.04
    },
    "requires": [
      "water_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "water_3": {
    "element": "water",
    "name": "Elemental Force",
    "description": "+8% water damage.",
    "effects": {
      "water_damage_multiplier": 0.08
    },
    "requires": [
      "water_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "water_4": {
    "element": "water",
    "name": "Deep Wells",
    "description": "Heal for an additional 4% of Water damage.",
    "effects": {
      "water_heal_ratio": 0.04
    },
    "requires": [
      "water_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "water_5": {
    "element": "water",
    "name": "Greater Mastery",
    "description": "+10% water damage.",
    "effects": {
      "water_damage_multiplier": 0.1
    },
    "requires": [
      "water_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "water_6": {
    "element": "water",
    "name": "Renewal",
    "description": "Heal for an additional 6% of Water damage.",
    "effects": {
      "water_heal_ratio": 0.06
    },
    "requires": [
      "water_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "water_7": {
    "element": "water",
    "name": "Living Ocean",
    "description": "+12% water damage. Heal for an additional 8% of Water damage.",
    "effects": {
      "water_damage_multiplier": 0.12,
      "water_heal_ratio": 0.08
    },
    "requires": [
      "water_5",
      "water_6"
    ],
    "tier": 4,
    "lane": 0
  },
  "ice_0": {
    "element": "ice",
    "name": "Ice Attunement",
    "description": "+5% ice damage.",
    "effects": {
      "ice_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "ice_1": {
    "element": "ice",
    "name": "Focused Power",
    "description": "+6% ice damage.",
    "effects": {
      "ice_damage_multiplier": 0.06
    },
    "requires": [
      "ice_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "ice_2": {
    "element": "ice",
    "name": "Chilling Touch",
    "description": "Using Ice reduces the enemy retaliation by 1.",
    "effects": {
      "ice_retaliation_reduction": 1
    },
    "requires": [
      "ice_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "ice_3": {
    "element": "ice",
    "name": "Elemental Force",
    "description": "+8% ice damage.",
    "effects": {
      "ice_damage_multiplier": 0.08
    },
    "requires": [
      "ice_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "ice_4": {
    "element": "ice",
    "name": "Cold Front",
    "description": "Ice reduces retaliation by 1 more.",
    "effects": {
      "ice_retaliation_reduction": 1
    },
    "requires": [
      "ice_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "ice_5": {
    "element": "ice",
    "name": "Greater Mastery",
    "description": "+10% ice damage.",
    "effects": {
      "ice_damage_multiplier": 0.1
    },
    "requires": [
      "ice_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "ice_6": {
    "element": "ice",
    "name": "Deep Freeze",
    "description": "Ice reduces retaliation by 1 more.",
    "effects": {
      "ice_retaliation_reduction": 1
    },
    "requires": [
      "ice_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "ice_7": {
    "element": "ice",
    "name": "Winter Crown",
    "description": "+12% ice damage. Ice reduces retaliation by 2 more.",
    "effects": {
      "ice_damage_multiplier": 0.12,
      "ice_retaliation_reduction": 2
    },
    "requires": [
      "ice_5",
      "ice_6"
    ],
    "tier": 4,
    "lane": 0
  },
  "nature_0": {
    "element": "nature",
    "name": "Nature Attunement",
    "description": "+5% nature damage.",
    "effects": {
      "nature_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "nature_1": {
    "element": "nature",
    "name": "Focused Power",
    "description": "+6% nature damage.",
    "effects": {
      "nature_damage_multiplier": 0.06
    },
    "requires": [
      "nature_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "nature_2": {
    "element": "nature",
    "name": "Venom Seed",
    "description": "Nature applies poison equal to 6% of its damage.",
    "effects": {
      "nature_poison_ratio": 0.06
    },
    "requires": [
      "nature_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "nature_3": {
    "element": "nature",
    "name": "Elemental Force",
    "description": "+8% nature damage.",
    "effects": {
      "nature_damage_multiplier": 0.08
    },
    "requires": [
      "nature_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "nature_4": {
    "element": "nature",
    "name": "Thornsap",
    "description": "Add 6% of Nature damage as poison.",
    "effects": {
      "nature_poison_ratio": 0.06
    },
    "requires": [
      "nature_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "nature_5": {
    "element": "nature",
    "name": "Greater Mastery",
    "description": "+10% nature damage.",
    "effects": {
      "nature_damage_multiplier": 0.1
    },
    "requires": [
      "nature_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "nature_6": {
    "element": "nature",
    "name": "Overgrowth",
    "description": "Add 8% of Nature damage as poison.",
    "effects": {
      "nature_poison_ratio": 0.08
    },
    "requires": [
      "nature_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "nature_7": {
    "element": "nature",
    "name": "Ancient Roots",
    "description": "+12% nature damage. Add 12% of Nature damage as poison.",
    "effects": {
      "nature_damage_multiplier": 0.12,
      "nature_poison_ratio": 0.12
    },
    "requires": [
      "nature_5",
      "nature_6"
    ],
    "tier": 4,
    "lane": 0
  },
  "earth_0": {
    "element": "earth",
    "name": "Earth Attunement",
    "description": "+5% earth damage.",
    "effects": {
      "earth_damage_multiplier": 0.05
    },
    "requires": [],
    "tier": 0,
    "lane": 0
  },
  "earth_1": {
    "element": "earth",
    "name": "Focused Power",
    "description": "+6% earth damage.",
    "effects": {
      "earth_damage_multiplier": 0.06
    },
    "requires": [
      "earth_0"
    ],
    "tier": 1,
    "lane": -1
  },
  "earth_2": {
    "element": "earth",
    "name": "Stone Skin",
    "description": "Using Earth grants 1 guard.",
    "effects": {
      "earth_guard": 1
    },
    "requires": [
      "earth_0"
    ],
    "tier": 1,
    "lane": 1
  },
  "earth_3": {
    "element": "earth",
    "name": "Elemental Force",
    "description": "+8% earth damage.",
    "effects": {
      "earth_damage_multiplier": 0.08
    },
    "requires": [
      "earth_1"
    ],
    "tier": 2,
    "lane": -1
  },
  "earth_4": {
    "element": "earth",
    "name": "Bedrock",
    "description": "Earth grants 1 additional guard.",
    "effects": {
      "earth_guard": 1
    },
    "requires": [
      "earth_2"
    ],
    "tier": 2,
    "lane": 1
  },
  "earth_5": {
    "element": "earth",
    "name": "Greater Mastery",
    "description": "+10% earth damage.",
    "effects": {
      "earth_damage_multiplier": 0.1
    },
    "requires": [
      "earth_3"
    ],
    "tier": 3,
    "lane": -1
  },
  "earth_6": {
    "element": "earth",
    "name": "Mountain Wall",
    "description": "Earth grants 1 additional guard.",
    "effects": {
      "earth_guard": 1
    },
    "requires": [
      "earth_4"
    ],
    "tier": 3,
    "lane": 1
  },
  "earth_7": {
    "element": "earth",
    "name": "Worldheart",
    "description": "+12% earth damage. Earth grants 2 additional guard.",
    "effects": {
      "earth_damage_multiplier": 0.12,
      "earth_guard": 2
    },
    "requires": [
      "earth_5",
      "earth_6"
    ],
    "tier": 4,
    "lane": 0
  }
,
  "fire_mastery": {"element": "fire", "name": "Fire Mastery", "description": "+3% fire damage per rank. No rank limit.", "effects": {"fire_damage_multiplier": 0.03}, "requires": ["fire_7"], "tier": 5, "lane": 0, "repeatable": true},
  "lightning_mastery": {"element": "lightning", "name": "Lightning Mastery", "description": "+3% lightning damage per rank. No rank limit.", "effects": {"lightning_damage_multiplier": 0.03}, "requires": ["lightning_7"], "tier": 5, "lane": 0, "repeatable": true},
  "water_mastery": {"element": "water", "name": "Water Mastery", "description": "+3% water damage per rank. No rank limit.", "effects": {"water_damage_multiplier": 0.03}, "requires": ["water_7"], "tier": 5, "lane": 0, "repeatable": true},
  "ice_mastery": {"element": "ice", "name": "Ice Mastery", "description": "+3% ice damage per rank. No rank limit.", "effects": {"ice_damage_multiplier": 0.03}, "requires": ["ice_7"], "tier": 5, "lane": 0, "repeatable": true},
  "nature_mastery": {"element": "nature", "name": "Nature Mastery", "description": "+3% nature damage per rank. No rank limit.", "effects": {"nature_damage_multiplier": 0.03}, "requires": ["nature_7"], "tier": 5, "lane": 0, "repeatable": true},
  "earth_mastery": {"element": "earth", "name": "Earth Mastery", "description": "+3% earth damage per rank. No rank limit.", "effects": {"earth_damage_multiplier": 0.03}, "requires": ["earth_7"], "tier": 5, "lane": 0, "repeatable": true}
}
