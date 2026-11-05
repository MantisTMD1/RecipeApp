# Recipe Rescuer

A SwiftUI recipe app for iOS that turns the ingredients you already have into dinner ideas. Recipe data from [TheMealDB](https://www.themealdb.com). Nutrition estimates use [USDA FoodData Central](https://fdc.nal.usda.gov).

## Features

- **Discover:** a featured recipe and a grid of random picks, with shuffle and categories
- **Kitchen:** add the ingredients you have and get recipe ideas ranked by what you're missing
- **Meal plan:** plan the week from any recipe and add everything you're missing to the shopping list in one tap
- **iCloud sync:** your kitchen, saved recipes, shopping list and meal plan stay up to date across your devices
- **Shopping list:** add missing ingredients from any recipe, check them off, and move them to your kitchen
- **Your own recipes:** add family recipes with a photo; they work everywhere, including recipe ideas
- **Cooking mode:** one large step at a time, screen kept awake, tap-to-start timers
- **Recipe scaling:** ½×, 1×, 2× or 3× amounts
- **Diet filters:** vegetarian, vegan, gluten-free and dairy-free
- **Estimated cooking times** and breakfast/lunch/dinner/dessert browsing
- **Browse by cuisine**
- **Nutrition estimates:** calories, protein, carbs, fat, fiber, sugar and sodium per serving, worked out from each recipe's ingredients
- **Favorites and search**
- A personal welcome greeting, set on first launch and editable in Settings
- Dark, light or system appearance

## Requirements

- Xcode 26 or later
- iOS 18 or later

## Getting started

1. Copy `RecipeApp/Services/APIKey.example.swift` to `RecipeApp/Services/APIKey.swift` (this file is ignored by git).
2. In the copy, uncomment the `APIKey` enum and set `mealDB` to your TheMealDB key. The free development key `1` works for local testing; App Store releases need a [supporter key](https://www.themealdb.com/api.php).
3. Open `RecipeApp.xcodeproj` in Xcode and run the `RecipeApp` scheme on a simulator or device.

## App icon

The icon is drawn in code. To regenerate it after editing `Design/make_icon.swift`:

```bash
swift Design/make_icon.swift RecipeApp/Assets.xcassets/AppIcon.appiconset
```

## Nutrition data

The app ships a table of ingredient nutrition in `RecipeApp/Data/nutrition.json`, so it makes no calls to USDA. To rebuild it, unzip USDA's SR Legacy JSON dataset from the [download page](https://fdc.nal.usda.gov/download-datasets/) into `build/fdc-bulk/`, then run:

```bash
python3 -I Design/build_nutrition.py
```

Review `build/nutrition-review.tsv` afterwards and correct any bad matches in `Design/nutrition_overrides.json`.

## Uploading to App Store Connect

The team has no registered devices, so archives are built unsigned. Export takes the app's permissions from the archive's signature, so sign it with the entitlements first or iCloud is lost without any error:

```sh
xcodebuild -project RecipeApp.xcodeproj -scheme RecipeApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/RecipeApp.xcarchive archive CODE_SIGNING_ALLOWED=NO
codesign --force --sign - --entitlements RecipeApp.entitlements build/RecipeApp.xcarchive/Products/Applications/RecipeApp.app
```

After any change to a SwiftData model, publish the new fields: run a Debug build with the `-InitCloudKitSchema` launch argument on a simulator signed in to iCloud, then deploy the schema to Production in the [CloudKit Console](https://icloud.developer.apple.com) before releasing. App Store and TestFlight builds can't sync until this is done, and fields can't be removed once they're in Production.

## License

The code is released under the [MIT License](LICENSE). Recipe text and images come from TheMealDB and are not covered by this license. USDA FoodData Central data is public domain (CC0 1.0).
