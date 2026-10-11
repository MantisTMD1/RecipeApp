# Recipe Rescue

A SwiftUI recipe app for iOS that turns the ingredients you already have into dinner ideas. Recipe data from [TheMealDB](https://www.themealdb.com).

## Features

- **Discover:** a featured recipe and a grid of random picks, with shuffle and categories
- **Kitchen:** add the ingredients you have and get recipe ideas ranked by what you're missing
- **Shopping list:** add missing ingredients from any recipe, check them off, and move them to your kitchen
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
