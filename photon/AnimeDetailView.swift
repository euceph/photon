import SwiftUI
import SwiftSoup

struct AnimeDetailView: View {
    let linkURL: String
    let posterURL: String
    let storedTitle: String
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var numberOfEpisodes: Int = 1
    @State private var type: String = ""
    @State private var isExpanded: Bool = false
    @State private var selectedEpisode: String? = nil
    @State private var premiereYear: String? = nil
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
                
                if type == "TV" {
                    Image(systemName: "tv").padding(8)
                } else if type == "Movie" {
                    Image(systemName: "film").padding(8)
                }
                
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
                
                if numberOfEpisodes > 0 {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(1...numberOfEpisodes, id: \.self) { episodeNumber in
                            NavigationLink(
                                destination: EpisodeView(episodeURL: "https://aniwave.se/anime-watch/\(storedTitle.lowercased().replacingOccurrences(of: " ", with: "-"))/ep-\(episodeNumber)")
                            ) {
                                Text("\(episodeNumber)")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(selectedEpisode == "\(episodeNumber)" ? .white : Color.gray)
                                    .frame(width: 40, height: 40)
                                    .background(selectedEpisode == "\(episodeNumber)" ? Color.black : Color(UIColor.systemGray5))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedEpisode == "\(episodeNumber)" ? Color.black : Color.gray, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding()
                } else {
                    Text("No episodes available.")
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
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                
                if let titleElement = try document.select("h1[itemprop=name]").first() {
                    let titleText = (try? titleElement.text()) ?? "Unknown Title"
                    DispatchQueue.main.async {
                        self.title = titleText
                    }
                }
                
                if let typeElement = try document.select("div.meta div:contains(Type:) span a").first() {
                    let extractedType = (try? typeElement.text()) ?? ""
                    DispatchQueue.main.async {
                        self.type = extractedType
                    }
                }
                
                if let descriptionElement = try document.select("div.synopsis.mb-3 div.content").first() {
                    let descriptionText = (try? descriptionElement.text()) ?? "No Description Available"
                    DispatchQueue.main.async {
                        self.description = descriptionText
                    }
                }
                
                
                if let episodesElement = try document.select("div.bmeta").first() {
                    let episodesText = try episodesElement.select("div.meta div:contains(Episodes:) span").first()?.text() ?? "0"
                    if let episodesCount = Int(episodesText) {
                        DispatchQueue.main.async {
                            self.numberOfEpisodes = episodesCount
                        }
                    }
                }
                
            } catch {
                print("Error parsing HTML: \(error)")
            }
        }.resume()
    }
}
