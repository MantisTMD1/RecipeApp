import Foundation

/// A cuisine to browse. `areaName` is the value TheMealDB stores on recipes, which isn't always
/// an adjective ("France", "United States"), and its `list.php?a=list` endpoint also returns
/// many names with no recipes, so the cuisines with recipes are listed here.
struct Cuisine: Identifiable, Hashable {
    let title: String
    let areaName: String

    var id: String { areaName }

    static let all: [Cuisine] = [
        Cuisine(title: "Algerian", areaName: "Algerian"),
        Cuisine(title: "American", areaName: "United States"),
        Cuisine(title: "Argentine", areaName: "Argentina"),
        Cuisine(title: "Australian", areaName: "Australian"),
        Cuisine(title: "British", areaName: "British"),
        Cuisine(title: "Canadian", areaName: "Canadian"),
        Cuisine(title: "Chinese", areaName: "Chinese"),
        Cuisine(title: "Croatian", areaName: "Croatian"),
        Cuisine(title: "Dutch", areaName: "Netherlands"),
        Cuisine(title: "Egyptian", areaName: "Egyptian"),
        Cuisine(title: "Filipino", areaName: "Filipino"),
        Cuisine(title: "French", areaName: "France"),
        Cuisine(title: "Greek", areaName: "Greek"),
        Cuisine(title: "Indian", areaName: "India"),
        Cuisine(title: "Irish", areaName: "Irish"),
        Cuisine(title: "Italian", areaName: "Italian"),
        Cuisine(title: "Jamaican", areaName: "Jamaican"),
        Cuisine(title: "Japanese", areaName: "Japanese"),
        Cuisine(title: "Kenyan", areaName: "Kenyan"),
        Cuisine(title: "Malaysian", areaName: "Malaysian"),
        Cuisine(title: "Mexican", areaName: "Mexican"),
        Cuisine(title: "Moroccan", areaName: "Moroccan"),
        Cuisine(title: "Norwegian", areaName: "Norway"),
        Cuisine(title: "Polish", areaName: "Polish"),
        Cuisine(title: "Portuguese", areaName: "Portuguese"),
        Cuisine(title: "Russian", areaName: "Russian"),
        Cuisine(title: "Saudi Arabian", areaName: "Saudi Arabian"),
        Cuisine(title: "Slovak", areaName: "Slovakia"),
        Cuisine(title: "Spanish", areaName: "Spanish"),
        Cuisine(title: "Syrian", areaName: "Syrian"),
        Cuisine(title: "Thai", areaName: "Thai"),
        Cuisine(title: "Tunisian", areaName: "Tunisian"),
        Cuisine(title: "Turkish", areaName: "Turkish"),
        Cuisine(title: "Ukrainian", areaName: "Ukrainian"),
        Cuisine(title: "Uruguayan", areaName: "Uruguayan"),
        Cuisine(title: "Venezuelan", areaName: "Venezuela"),
        Cuisine(title: "Vietnamese", areaName: "Vietnamese"),
    ]
}
