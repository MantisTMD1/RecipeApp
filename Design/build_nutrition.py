#!/usr/bin/env python3
"""Builds RecipeApp/Data/nutrition.json from USDA FoodData Central.

The app ships this table rather than calling USDA, so it needs no USDA key and works offline.
FoodData Central data is public domain (CC0 1.0).

Usage:
    1. Download "SR Legacy" (JSON) from https://fdc.nal.usda.gov/download-datasets/ and unzip it
       into build/fdc-bulk/.
    2. python3 -I Design/build_nutrition.py

Recipes and ingredient names come from TheMealDB using the key in APIKey.swift. Recipes are
cached in build/mealdb-recipes.json. Check build/nutrition-review.tsv after a run, and correct
bad matches in Design/nutrition_overrides.json, keyed by normalized ingredient name:
    {"query": "..."}      match this instead of the name
    {"fdcId": 123}        use this exact food
    {"contains": "..."}   use the shortest description containing this exact text
    {"sameAs": "onion"}   reuse another ingredient's food
    {"skip": true}        leave out of the table
    "density"/"each"/"slice" set portion sizes where USDA's are missing or unsuitable
"""
import json
import re
import string
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BULK = ROOT / "build" / "fdc-bulk"
RECIPES = ROOT / "build" / "mealdb-recipes.json"
OUTPUT = ROOT / "RecipeApp" / "Data" / "nutrition.json"
REVIEW = ROOT / "build" / "nutrition-review.tsv"
OVERRIDES = ROOT / "Design" / "nutrition_overrides.json"

NUTRIENTS = {"208": "kcal", "203": "protein", "205": "carbs", "204": "fat",
             "291": "fiber", "269": "sugar", "307": "sodium"}

# Descriptions containing these are rarely what a recipe ingredient means.
PENALTIES = {
    "babyfood": 80, "baby": 40, "infant": 80, "fast": 50, "restaurant": 60, "breaded": 40, "battered": 40,
    "school": 50, "usda": 25, "commodity": 25, "imitation": 30, "substitute": 30, "fat-free": 20, "nonfat": 20,
    "reduced": 15, "low": 12, "lowfat": 15, "light": 12, "diet": 30, "formulated": 25, "frozen": 8, "canned": 6,
    "dehydrated": 15, "dry": 4, "cooked": 8, "boiled": 8, "fried": 15, "roasted": 6, "microwaved": 15,
    "candie": 40, "snack": 40, "cereal": 15, "soup": 12, "sauce": 8, "pie": 25, "deli": 25, "prepackaged": 25,
    "oscar": 60, "mayer": 60, "kraft": 40, "campbell": 40, "brand": 25,
}
BONUSES = {"raw": 14, "fresh": 6, "whole": 3, "regular": 3, "all-purpose": 4}


def normalize(name):
    """Must match IngredientMatcher.normalize in the app."""
    words = []
    for word in name.lower().strip().split():
        if word.endswith("oes"):
            word = word[:-2]
        elif word.endswith("s") and not word.endswith("ss") and len(word) > 3:
            word = word[:-1]
        words.append(word)
    return " ".join(words)


def tokens(text):
    return [normalize(t) for t in re.findall(r"[a-z-]+", text.lower())]


def mealdb(path):
    source = (ROOT / "RecipeApp" / "Services" / "APIKey.swift").read_text()
    key = re.search(r'mealDB\s*=\s*"([^"]+)"', source).group(1)
    url = f"https://www.themealdb.com/api/json/v2/{key}/{path}"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response).get("meals") or []


def load_recipes():
    if not RECIPES.exists():
        recipes = {}
        for letter in string.ascii_lowercase + string.digits:
            for meal in mealdb(f"search.php?f={letter}"):
                recipes[meal["idMeal"]] = meal
        RECIPES.write_text(json.dumps(list(recipes.values())))
    return json.loads(RECIPES.read_text())


def load_foods():
    path = next(BULK.glob("*sr_legacy*.json"))
    foods = []
    for raw in json.loads(path.read_text())["SRLegacyFoods"]:
        foods.append({
            "fdcId": raw["fdcId"],
            "description": raw["description"],
            "tokens": tokens(raw["description"]),
            "head": tokens(raw["description"].split(",")[0]),
            "nutrients": {n["nutrient"]["number"]: n.get("amount", 0) for n in raw["foodNutrients"]
                          if n["nutrient"]["number"] in NUTRIENTS},
            "portions": raw.get("foodPortions", []),
        })
    return foods


def score(wanted, food):
    described = food["tokens"]
    # USDA leads with the food itself ("Onions, raw"), so an early match means the right food.
    value = 100 - 10 * max(described.index(t) for t in wanted)
    value -= 2 * (len(described) - len(wanted))
    if all(t in food["head"] for t in wanted):
        value += 30
    for word in described:
        value -= PENALTIES.get(word, 0)
        value += BONUSES.get(word, 0)
    return value


def best_match(query, index):
    wanted = tokens(query)
    if not wanted or any(t not in index for t in wanted):
        return None, None
    candidates = set.intersection(*(index[t] for t in wanted))
    scored = [(score(wanted, food), food["fdcId"], food) for food in map(FOODS.__getitem__, candidates)]
    if not scored:
        return None, None
    best = max(scored, key=lambda item: (item[0], -item[1]))
    return best[0], best[2]


def is_clear(name, food):
    wanted = tokens(name)
    return (all(t in food["head"] for t in wanted)
            and len(food["head"]) <= len(wanted) + 1
            and not any(word in PENALTIES for word in food["tokens"]))


def portion_sizes(rows):
    """Turns USDA's household portions into density, each and slice weights."""
    density = each = slice_ = None
    each_rank = 99
    ranks = [("medium", 1, 1), ("clove", 1, 1), ("each", 2, 1), ("whole", 2, 1), ("fruit", 2, 1),
             ("large", 3, 1.25), ("small", 4, 0.75), ("piece", 5, 1), ("unit", 5, 1)]
    for row in rows:
        grams = row.get("gramWeight")
        if not grams:
            continue
        grams /= row.get("amount") or 1
        words = re.findall(r"[a-z]+", (row.get("modifier") or "").lower())
        # A cup of whipped cream weighs half what a cup of cream does.
        if density is None and "whipped" not in words:
            for name, ml in [("cup", 240), ("tbsp", 15), ("tablespoon", 15), ("tsp", 5), ("teaspoon", 5)]:
                if name in words:
                    density = round(grams / ml, 3)
                    break
        if slice_ is None and "slice" in words:
            slice_ = round(grams, 1)
        # "1 slice, medium" or "1 cup, chopped" describe part of the food, not one whole item.
        if set(words) & {"slice", "slices", "cup", "cups", "tbsp", "tsp", "ring", "rings", "wedge", "oz"}:
            continue
        for name, order, size in ranks:
            if name in words and order < each_rank:
                each_rank = order
                each = round(grams / size, 1)
                break
    return density, each, slice_


FOODS = {}


def main():
    foods = load_foods()
    FOODS.update({food["fdcId"]: food for food in foods})
    index = defaultdict(set)
    for food in foods:
        for token in set(food["tokens"]):
            index[token].add(food["fdcId"])

    overrides = json.loads(OVERRIDES.read_text()) if OVERRIDES.exists() else {}
    usage = Counter()
    for recipe in load_recipes():
        for i in range(1, 21):
            name = (recipe.get(f"strIngredient{i}") or "").strip()
            if name:
                usage[normalize(name)] += 1
    # The full ingredient list also covers what people pick for their own recipes.
    for item in mealdb("list.php?i=list"):
        usage.setdefault(normalize(item["strIngredient"]), 0)
    for name in overrides:
        usage.setdefault(name, 0)

    table, review, ids = {}, [], {}
    for name, _ in usage.most_common():
        rule = overrides.get(name, {})
        if rule.get("skip") or "sameAs" in rule:
            continue
        if "fdcId" in rule:
            value, food = "fixed", FOODS[rule["fdcId"]]
        elif "contains" in rule:
            matches = [f for f in foods if rule["contains"] in f["description"]]
            value, food = "fixed", min(matches, key=lambda f: len(f["description"])) if matches else None
        else:
            value, food = best_match(rule.get("query", name), index)
            # Without a reviewed rule, keep only clear matches: the name must lead the description
            # and nothing about it can suggest a different product ("Cinnamon buns", "Bacon, meatless").
            if food and "query" not in rule and not is_clear(name, food):
                review.append((usage[name], name, food["fdcId"], "REJECTED " + food["description"], "", value))
                continue
        if food is None:
            review.append((usage[name], name, "", "NO MATCH", "", ""))
            continue
        density, each, slice_ = portion_sizes(food["portions"])
        entry = {field: round(food["nutrients"].get(number, 0) or 0, 2) for number, field in NUTRIENTS.items()}
        entry.update(density=rule.get("density", density), each=rule.get("each", each), slice=rule.get("slice", slice_))
        table[name] = {k: v for k, v in entry.items() if v is not None}
        ids[name] = food["fdcId"]
        review.append((usage[name], name, food["fdcId"], food["description"], entry["kcal"], value))

    # Repeated so a rule can point at another "sameAs".
    pending = {name: rule for name, rule in overrides.items() if "sameAs" in rule}
    while True:
        ready = {name: rule for name, rule in pending.items() if rule["sameAs"] in table}
        if not ready:
            break
        for name, rule in ready.items():
            entry = dict(table[rule["sameAs"]])
            entry.update({k: rule[k] for k in ("density", "each", "slice") if k in rule})
            table[name] = entry
            ids[name] = ids[rule["sameAs"]]
            review.append((usage[name], name, ids[name], "same as " + rule["sameAs"], entry["kcal"], ""))
            del pending[name]
    for name, rule in pending.items():
        review.append((usage[name], name, "", "BROKEN sameAs " + rule["sameAs"], "", ""))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(table, separators=(",", ":"), sort_keys=True) + "\n")
    review.sort(key=lambda row: -row[0])
    REVIEW.write_text("uses\tingredient\tfdcId\tUSDA food\tkcal/100g\tscore\n"
                      + "".join("\t".join(map(str, row)) + "\n" for row in review))
    matched = sum(c for n, c in usage.items() if n in table)
    print(f"{len(table)} foods; {matched}/{sum(usage.values())} recipe ingredient uses matched; {OUTPUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
