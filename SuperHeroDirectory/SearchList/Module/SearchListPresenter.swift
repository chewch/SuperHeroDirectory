//
//  SearchListPresenter.swift
//  SuperHeroDirectory
//
//  Created by Matthew Korporaal on 8/8/20.
//  Copyright © 2020 Matthew Korporaal. All rights reserved.
//

import UIKit

// MARK: - SearchListPresenterProtocol - Declaration

protocol SearchListPresenterProtocol {
    /// The presenter fetches data from use case
    func fetch()
    /// The presenter fetches names from use case with search parameter
    func fetch(startsWith: String)
    /// Presenter fetches more of the current string
    func fetchMore(startsWith: String)
    /// The presenter reload data from the use case
    func refresh()
    /// View did Select group
    func view(didSelect presentable: SearchListViewPresentable)
}

// MARK: - SearchListPresenter Module Presenter

final class SearchListPresenter {
    
    // MARK: - State
    
    private struct State {
        
        var paginationUseCase: PaginationUseCaseProtocol
        var isLoading = false

        // MARK: - helpers
        
        var pageInfo: PageInfo { paginationUseCase.pageInfo }
        
        mutating func resetOffset() { paginationUseCase.resetOffset() }
        mutating func setOffset() { paginationUseCase.setOffset() }
    }
    
    weak var router: SearchListRouterProtocol?
    weak var view: SearchListViewControllerProtocol?
    
    private let getSuperheroUseCase: GetSuperheroUseCaseProtocol
    
    private var state: State {
        didSet {
            state.isLoading ? view?.startLoading() : view?.stopLoading()
        }
    }
    
    init(getSuperheroUseCase: GetSuperheroUseCaseProtocol,
         paginationUseCase: PaginationUseCaseProtocol) {
        self.getSuperheroUseCase = getSuperheroUseCase
        self.state = State(paginationUseCase: paginationUseCase)
    }
}

// MARK: - SearchListPresenterProtocol - implementation

extension SearchListPresenter: SearchListPresenterProtocol {
    
    func fetch() {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.setOffset()
        getSuperheroUseCase.fetch(with: state.pageInfo)
            .onSuccess(handleSuccess).onFailure(handleError)
    }
    
    func fetch(startsWith: String) {
        guard startsWith.count >= Constants.minSearchLength else { return }
        state.isLoading = true
        state.resetOffset()
        getSuperheroUseCase.fetch(startsWith: startsWith, pageInfo: state.pageInfo)
            .onSuccess(handleSuccess).onFailure(handleError)
    }
    
    func fetchMore(startsWith: String) {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.setOffset()
        getSuperheroUseCase.fetchMore(startsWith: startsWith, pageInfo: state.pageInfo)
            .onSuccess(handleSuccess).onFailure(handleError)
    }

    func refresh() {
        state.isLoading = true
        state.resetOffset()
        getSuperheroUseCase.refresh(with: state.pageInfo)
            .onSuccess(handleSuccess).onFailure(handleError)
    }
    
    func view(didSelect presentable: SearchListViewPresentable) {
        router?.showDetails(with: presentable.superhero)
    }
}

// MARK: - Private methods

private extension SearchListPresenter {

    func handleSuccess(_ heroes: [SuperheroType]) {
        state.isLoading = false
        let presentables = heroes.map { SearchListViewModel(superhero: $0) }
        view?.consume(presentables: presentables)
    }

    func handleError(_ error: Error) {
        state.isLoading = false
        let errorMessage = (error as? HTTPError)
            .flatMap { $0.localizedDescription } ?? L10n.General.Error.text
        view?.show(title: L10n.General.Error.title, message: errorMessage)
    }
    
    enum Constants {
        static let minSearchLength = 3
    }
}
