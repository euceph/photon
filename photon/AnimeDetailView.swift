import SwiftUI
import SwiftSoup

struct AnimeDetailView: View {
    let linkURL: String
    let posterURL: String
    let storedTitle: String
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isMovie: Bool = false
    @State private var isTV: Bool = false
    @State private var isExpanded: Bool = false
    private let descriptionThreshold = 150

    var body: some View {
            ScrollView {
                VStack(alignment: .center) {
                    CachedImageView(urlString: posterURL)
                        .frame(maxWidth: .infinity, maxHeight: 500)
                        .cornerRadius(16)
                        .padding()

                    Text(title)
                        .font(.title)
                        .bold()
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                    

                    if !description.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(isExpanded ? description : truncatedDescription())
                                .font(.body)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                                .shadow(radius: 1)

                            if description.count > descriptionThreshold {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            isExpanded.toggle()
                                        }
                                    }) {
                                        Text(isExpanded ? "less..." : "more...")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.trailing)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onAppear {
                fetchAnimeDetails(from: linkURL)
            }
        }

        private func truncatedDescription() -> String {
            if description.count > descriptionThreshold {
                return String(description.prefix(descriptionThreshold)) + "..."
            } else {
                return description
            }
        }

        func fetchAnimeDetails(from url: String) {
        guard let fullURL = URL(string: "https://aniwave.se\(url)") else { return }

        URLSession.shared.dataTask(with: fullURL) { data, response, error in
            guard let data = data, error == nil else { return }

            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)

                // Extract the title
                if let titleElement = try document.select("h1[itemprop=name]").first() {
                    DispatchQueue.main.async {
                        self.title = (try? titleElement.text()) ?? "Unknown Title"
                    }
                }

                // Extract the description
                if let descriptionElement = try document.select("div.synopsis.mb-3 div.content").first() {
                    DispatchQueue.main.async {
                        self.description = (try? descriptionElement.text()) ?? "No Description Available"
                    }
                }

            } catch {
                print("Error parsing HTML: \(error)")
            }
        }.resume()
    }
}
