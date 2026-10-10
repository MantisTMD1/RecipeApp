# RecipeApp

A SwiftUI recipe app for iOS, powered by [TheMealDB](https://www.themealdb.com).

## Features

- **Discover:** a featured recipe and a grid of random picks, with shuffle and categories
- **Kitchen:** add the ingredients you have and get recipe ideas ranked by what you're missing
- **Shopping list:** add missing ingredients from any recipe, check them off, and move them to your kitchen
- **Favorites and search**
- Dark, light or system appearance

## Requirements

- Xcode 26 or later
- iOS 18 or later

## Getting started

Open `RecipeApp.xcodeproj` in Xcode and run the `RecipeApp` scheme on a simulator or device.

The app uses TheMealDB's free development key (`1`). Before publishing to the App Store, replace it with a supporter key in `RecipeApp/Services/MealDBClient.swift`.

## App icon

The icon is drawn in code. To regenerate it after editing `Design/make_icon.swift`:

```bash
swift Design/make_icon.swift RecipeApp/Assets.xcassets/AppIcon.appiconset
```
