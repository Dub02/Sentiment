import SwiftUI
import MapKit

struct ContentView: View {
    @State private var selectedBusinessName: String = ""
    @State private var selectedBusinessAddress: String = ""
    @State private var isPresentingMap = false
    @State private var showResponse: Bool = false
    @State private var sentimentScore: Int = 0
    @State private var positives: [String] = []
    @State private var negatives: [String] = []
    @State private var showResultView = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchCompleterManager = SearchCompleterManager()

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                    .frame(height: 25)

                Image("transparent_image")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 175)
                    .padding(.top, 0)

                Spacer()

                Button(action: {
                    isPresentingMap = true
                }) {
                    Text("Search for Nearby Businesses")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $isPresentingMap) {
                    MapView(
                        selectedBusinessName: $selectedBusinessName,
                        selectedBusinessAddress: $selectedBusinessAddress,
                        isPresentingMap: $isPresentingMap,
                        currentLocation: locationManager.location,
                        onBusinessSelected: { name, address in
                            self.selectedBusinessName = name
                            self.selectedBusinessAddress = address
                            self.submitBusinessData()
                        },
                        searchCompleterManager: searchCompleterManager
                    )
                }

                Spacer()

                HStack {
                    Button(action: {
                        // Refresh home page
                    }) {
                        Text("Home")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        // Help
                    }) {
                        Text("Help")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 20)

                NavigationLink(destination: ResultView(sentimentScore: $sentimentScore, positives: $positives, negatives: $negatives, showResultView: $showResultView), isActive: $showResultView) {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
    }

    private func submitBusinessData() {
        let networkManager = NetworkManager()
        networkManager.sendBusinessData(businessName: selectedBusinessName, businessAddress: selectedBusinessAddress) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let json):
                    if let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        self.parseResponse(content)
                        self.showResultView = true
                    } else {
                        print("Invalid response format")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
    }

    private func parseResponse(_ response: String) {
        let lines = response.split(separator: "\n")
        self.positives = []
        self.negatives = []

        for line in lines {
            if line.starts(with: "Public Sentiment Score:") {
                if let score = Int(line.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) {
                    self.sentimentScore = score
                    print("Public Sentiment Score: \(score)")
                }
            } else if line.starts(with: "Positives:") {
                self.positives = extractItems(from: lines, startingWith: "Positives:")
                print("Positives: \(self.positives.joined(separator: ", "))")
            } else if line.starts(with: "Negatives:") {
                self.negatives = extractItems(from: lines, startingWith: "Negatives:")
                print("Negatives: \(self.negatives.joined(separator: ", "))")
            }
        }
    }

    private func extractItems(from lines: [Substring], startingWith prefix: String) -> [String] {
        var items: [String] = []
        var collecting = false

        for line in lines {
            if line.starts(with: prefix) {
                collecting = true
                continue
            }

            if collecting {
                if line.starts(with: "1.") || line.starts(with: "2.") {
                    items.append(line.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    break
                }
            }
        }

        return items
    }
}

struct ResultView: View {
    @Binding var sentimentScore: Int
    @Binding var positives: [String]
    @Binding var negatives: [String]
    @Binding var showResultView: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Public Sentiment Score")
                .font(.headline)
                .padding(.bottom, 5)

            Text("\(sentimentScore)")
                .font(.largeTitle)
                .bold()
                .foregroundColor(scoreColor(score: sentimentScore))
                .padding(.bottom, 20)

            VStack(alignment: .leading) {
                Text("What people liked")
                    .font(.headline)
                    .padding(.bottom, 5)

                ForEach(positives, id: \.self) { positive in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(positive)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 2)
                }
            }

            VStack(alignment: .leading) {
                Text("What people didn't like")
                    .font(.headline)
                    .padding(.bottom, 5)

                ForEach(negatives, id: \.self) { negative in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.red)
                        Text(negative)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 2)
                }
            }

            Button(action: {
                self.showResultView = false
            }) {
                Text("Back")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }

    func scoreColor(score: Int) -> Color {
        switch score {
        case 0..<20:
            return Color(red: 139 / 255, green: 0, blue: 0)
        case 20..<40:
            return Color(red: 165 / 255, green: 42 / 255, blue: 42 / 255)
        case 40..<60:
            return Color.orange
        case 60..<80:
            return Color.yellow
        case 80...100:
            return Color.green
        default:
            return Color.gray
        }
    }
}

