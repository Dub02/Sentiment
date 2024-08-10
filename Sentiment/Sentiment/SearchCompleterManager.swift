import Foundation
import MapKit

class SearchCompleterManager: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    var searchCompleter: MKLocalSearchCompleter

    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()
        searchCompleter.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }

    func updateSearchQuery(_ query: String) {
        searchCompleter.queryFragment = query
    }
}
