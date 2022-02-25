//
//  SearchedListViewDataSource.swift
//  NowPlayingList
//
//  Created by Yongwoo Marco on 2022/02/25.
//

import UIKit

protocol SearchMovieViewModel {
    func requestSearchMovie(of text: String)
    func resetDataSource()
}

class SearchedListViewDataSource: NSObject {
    typealias ChangedListCompletion = () -> Void
    typealias SelectedItmeCompletion = (Movie) -> Void
    
    private var changedListCompletion: ChangedListCompletion?
    private var selectedItmeCompletion: SelectedItmeCompletion?
    
    private let networkManager: SearchingMovieNetworkManager
    private var lastPage: Int = 1
    private var totalPage: Int = 0
    private var currentSearchWord: String = ""
    private var movies: [Movie] = [] {
        didSet {
            changedListCompletion?()
        }
    }
    
    init(networkManager: SearchingMovieNetworkManager,
         changedListCompletion: @escaping ChangedListCompletion,
         selectedItmeCompletion: @escaping SelectedItmeCompletion) {
        self.networkManager = networkManager
        self.changedListCompletion = changedListCompletion
        self.selectedItmeCompletion = selectedItmeCompletion
    }
}

extension SearchedListViewDataSource: SearchMovieViewModel {
    func requestSearchMovie(of text: String = "") {
        if !text.isEmpty { currentSearchWord = text }
        guard let url = NowPlayingListAPI.searching(text, lastPage).makeURL() else {
            NSLog("\(#function) - URL 생성 실패")
            return
        }
        networkManager.loadNowPlayingList(url: url) { page in
            self.movies.append(contentsOf: page.results)
            self.lastPage = page.page
            self.totalPage = page.totalPages
        }
    }
    
    func resetDataSource() {
        movies = []
        lastPage = 1
        totalPage = 0
    }
}

extension SearchedListViewDataSource: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SearchedListViewCell.className, for: indexPath) as? SearchedListViewCell else {
            return UITableViewCell()
        }
        
        let movie = movies[indexPath.row]
        let nsPath = NSString(string: movie.posterPath)
        cell.configureData(title: movie.title, date: movie.releaseDate,rated: movie.rated)
        
        if let cachedImage = ImageCacheManager.shared.object(forKey: nsPath) {
            cell.configureImage(cachedImage)
        } else {
            DispatchQueue.global().async {
                guard let imageURL = NowPlayingListAPI.makeImageURL(movie.posterPath) else {
                    NSLog("\(#function) - 포스터 URL 생성 실패")
                    return
                }
                if let imageData = NSData(contentsOf: imageURL),
                    let image = UIImage(data: Data(imageData)) {
                    ImageCacheManager.shared.setObject(image, forKey: nsPath)
                    DispatchQueue.main.async {
                        if indexPath == tableView.indexPath(for: cell) {
                            cell.configureImage(image)
                        }
                    }
                }
            }
        }
        
        return cell
    }
}

extension SearchedListViewDataSource: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if lastPage < totalPage, indexPath.item == (movies.count / 2) {
            lastPage += 1
            requestSearchMovie()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let seletedMovie = movies[indexPath.row]
        selectedItmeCompletion?(seletedMovie)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = UIScreen.main.bounds.height / 5
        return height
    }
}
