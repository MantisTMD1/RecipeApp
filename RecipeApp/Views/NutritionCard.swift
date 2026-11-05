import SwiftUI

/// Estimated nutrition per serving, shown on the recipe screen. Doubling a recipe also doubles
/// its servings, so the numbers only move when the person changes the serving count.
struct NutritionCard: View {
    let estimate: NutritionEstimate
    let scale: RecipeScale
    @Binding var servings: Int

    private var perServing: NutritionFacts {
        estimate.total.multiplied(by: scale.rawValue / Double(max(servings, 1)))
    }

    var body: some View {
        let facts = perServing
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nutrition").font(.title2.bold())
                Spacer()
                Text("Estimate")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: .capsule)
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(facts.calories.formatted(.number.precision(.fractionLength(0)).grouping(.automatic)))
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                    Text("calories per serving")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    macro("Protein", grams: facts.protein)
                    macro("Carbs", grams: facts.carbs)
                    macro("Fat", grams: facts.fat)
                }

                VStack(spacing: 6) {
                    detail("Fiber", value: "\(Int(facts.fiber.rounded())) g")
                    detail("Sugar", value: "\(Int(facts.sugar.rounded())) g")
                    detail("Sodium", value: "\(Int(facts.sodium.rounded())) mg")
                }

                Divider()

                Stepper(value: $servings, in: 1...48) {
                    Text("Makes \(servings) \(servings == 1 ? "serving" : "servings")")
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding()
            .background(.background.secondary, in: .rect(cornerRadius: 16))

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sensoryFeedback(.selection, trigger: servings)
    }

    private var footnote: String {
        var text = "Worked out from the ingredients using USDA FoodData Central, so treat it as a rough guide."
        if estimate.knownIngredients < estimate.countedIngredients {
            text += " Based on \(estimate.knownIngredients) of \(estimate.countedIngredients) ingredients."
        }
        return text
    }

    private func macro(_ name: String, grams: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams.rounded())) g")
                .font(.headline)
                .contentTransition(.numericText())
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
