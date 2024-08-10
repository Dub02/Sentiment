import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var selectedBusinessName: String
    @Binding var selectedBusinessAddress: String
    @Binding var isPresentingMap: Bool
    var currentLocation: CLLocation?
    var onBusinessSelected: (String, String) -> Void
    @ObservedObject var searchCompleterManager: SearchCompleterManager

    class Coordinator: NSObject, MKMapViewDelegate, UISearchBarDelegate {
        var parent: MapView
        var mapView: MKMapView?

        init(parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation as? MKPointAnnotation else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = annotation.title
            request.region = mapView.region

            let search = MKLocalSearch(request: request)
            search.start { (response, error) in
                guard let mapItem = response?.mapItems.first else { return }
                self.parent.selectedBusinessName = mapItem.name ?? "Unknown"
                self.parent.selectedBusinessAddress = mapItem.placemark.title ?? "Unknown Address"
                self.parent.isPresentingMap = false
                self.parent.onBusinessSelected(self.parent.selectedBusinessName, self.parent.selectedBusinessAddress)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Business"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView!.canShowCallout = true
                annotationView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                annotationView!.annotation = annotation
            }
            return annotationView
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.searchCompleterManager.updateSearchQuery(searchText)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            if let mapView = mapView {
                parent.performSearch(query: searchBar.text ?? "", mapView: mapView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        if let location = currentLocation {
            let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            mapView.setRegion(region, animated: true)
        }

        let searchBar = UISearchBar(frame: .zero)
        searchBar.placeholder = "Search for nearby businesses"
        searchBar.delegate = context.coordinator

        let suggestionsListView = SuggestionsListView(suggestions: $searchCompleterManager.results, currentLocation: currentLocation) { suggestion in
            context.coordinator.parent.selectSuggestion(suggestion: suggestion, mapView: mapView)
        }

        let stackView = UIStackView(arrangedSubviews: [searchBar, mapView, UIHostingController(rootView: suggestionsListView).view])
        stackView.axis = .vertical
        stackView.spacing = 0

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // map update when currlocate changes
        if let mapView = context.coordinator.mapView, let location = currentLocation {
            let region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            mapView.setRegion(region, animated: true)
        }
    }

    func performSearch(query: String, mapView: MKMapView) {
        guard let location = currentLocation else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else { return }
            let items = response.mapItems
            mapView.removeAnnotations(mapView.annotations)
            let annotations = items.map { item -> MKPointAnnotation in
                let annotation = MKPointAnnotation()
                annotation.coordinate = item.placemark.coordinate
                annotation.title = item.name
                annotation.subtitle = item.placemark.title
                return annotation
            }
            mapView.addAnnotations(annotations)
        }
    }

    func selectSuggestion(suggestion: MKLocalSearchCompletion, mapView: MKMapView) {
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            guard let mapItem = response?.mapItems.first else { return }
            self.selectedBusinessName = mapItem.name ?? "Unknown"
            self.selectedBusinessAddress = mapItem.placemark.title ?? "Unknown Address"
            self.isPresentingMap = false
            self.onBusinessSelected(self.selectedBusinessName, self.selectedBusinessAddress)
        }
    }
}

struct SuggestionsListView: View {
    @Binding var suggestions: [MKLocalSearchCompletion]
    var currentLocation: CLLocation?
    var onSelectSuggestion: (MKLocalSearchCompletion) -> Void

    var body: some View {
        List(suggestions, id: \.self) { suggestion in
            Button(action: {
                onSelectSuggestion(suggestion)
            }) {
                VStack(alignment: .leading) {
                    Text(suggestion.title)
                        .font(.headline)
                    Text(suggestion.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

