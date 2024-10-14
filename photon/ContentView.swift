import SwiftUI
import SwiftSoup
import Combine
import UIKit

struct Anime: Identifiable {
    let id = UUID()
    let title: String
    let posterURL: String
    let seriesURL: String
}

class AnimeScraper: ObservableObject {
    @Published var animes: [Anime] = []
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var searchQuery: String = ""
    @Published var noResults = false
    
    func fetchAnimeData(query: String = "", page: Int = 1) {
        var urlString: String
        
        if query.isEmpty {
            urlString = "https://aniwave.se/trending-anime/?page=\(page)"
        } else {
            let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            urlString = "https://aniwave.se/filter?keyword=\(formattedQuery)&page=\(page)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                
                if try document.text().contains("No matching records found") {
                    DispatchQueue.main.async {
                        self.animes = []
                        self.noResults = true
                    }
                    return
                }
                
                let animeElements = try document.select("div.item")
                
                var fetchedAnimes = [Anime]()
                for element in animeElements {
                    let title = try element.select("a.name").text()
                    let posterURL = try element.select("img").attr("src")
                    let seriesURL = try element.select("a.name").attr("href")
                    
                    let anime = Anime(title: title, posterURL: posterURL, seriesURL: seriesURL)
                    fetchedAnimes.append(anime)
                }
                
                var extractedTotalPages = 1
                
                if let lastPageElement = try document.select("ul.pagination li a[rel=last]").first() {
                    let lastPageURL = try lastPageElement.attr("href")
                    if let lastPageNumber = lastPageURL.components(separatedBy: "page=").last {
                        extractedTotalPages = Int(lastPageNumber) ?? 1
                    }
                }
                
                DispatchQueue.main.async {
                    self.animes = fetchedAnimes
                    self.noResults = fetchedAnimes.isEmpty
                    self.totalPages = extractedTotalPages
                }
            } catch {
                print("Error parsing HTML: \(error)")
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    private var urlString: String?
    private var retries = 0
    private var cancellable: AnyCancellable?
    
    func loadImage(from urlString: String) {
        self.urlString = urlString
        
        if let cachedImage = ImageCache.shared.object(forKey: urlString as NSString) {
            self.image = cachedImage
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fetchedImage in
                guard let self = self else { return }
                if let fetchedImage = fetchedImage {
                    ImageCache.shared.setObject(fetchedImage, forKey: urlString as NSString)
                    self.image = fetchedImage
                } else {
                    if self.retries < 3 {
                        self.retries += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.loadImage(from: urlString)
                        }
                    }
                }
            }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

struct CachedImageView: View {
    @StateObject private var imageLoader = ImageLoader()
    let urlString: String
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: .infinity)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            imageLoader.loadImage(from: urlString)
        }
        .onDisappear {
            imageLoader.cancel()
        }
    }
}

struct ContentView: View {
    @StateObject private var scraper = AnimeScraper()
    @State private var isShowingSearchSheet = false
    @State private var isSearching = false
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            VStack {
                if scraper.noResults {
                    Text("no results found")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150)), GridItem(.adaptive(minimum: 150))], spacing: 16) {
                                ForEach(scraper.animes) { anime in
                                    NavigationLink(destination: AnimeDetailView(linkURL: anime.seriesURL, posterURL: anime.posterURL, storedTitle: anime.title)) {
                                        VStack {
                                            CachedImageView(urlString: anime.posterURL)
                                                .frame(height: 200)
                                            
                                            Text(anime.title)
                                                .font(.headline)
                                                .multilineTextAlignment(.center)
                                                .padding(.top, 8)
                                        }
                                        .padding()
                                        .foregroundColor(colorScheme == .light ? .black : .white)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: scraper.animes.count) { _ in
                            scrollProxy.scrollTo(scraper.animes.last?.id, anchor: .bottom)
                        }
                        
                        HStack {
                            Button(action: {
                                if scraper.currentPage > 1 {
                                    scraper.currentPage -= 1
                                    scraper.fetchAnimeData(query: isSearching ? searchText : "", page: scraper.currentPage)
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title)
                            }
                            .disabled(scraper.currentPage == 1)
                            
                            Spacer()
                            
                            Text("Page \(scraper.currentPage) of \(scraper.totalPages)")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button(action: {
                                scraper.currentPage += 1
                                scraper.fetchAnimeData(query: isSearching ? searchText : "", page: scraper.currentPage)
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title)
                            }
                            .disabled(scraper.currentPage == scraper.totalPages)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(isSearching ? "\(searchText)" : "Trending Anime")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        scraper.searchQuery = ""
                        scraper.currentPage = 1
                        scraper.totalPages = 1
                        scraper.fetchAnimeData()
                        isSearching = false
                    }) {
                        Image(systemName: "house")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingSearchSheet.toggle()
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $isShowingSearchSheet) {
                VStack {
                    TextField("Search anime...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button("Search") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
                        scraper.currentPage = 1
                        scraper.fetchAnimeData(query: searchText, page: 1)
                        //                        searchText = ""
                        isSearching = true
                        isShowingSearchSheet = false
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onAppear {
            scraper.fetchAnimeData()
        }
    }
}


#Preview {
    ContentView()
}
