//
//  IndexedCountryListView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/1/26.
//

import SwiftUI
import UIKit

struct IndexedCountryListView: UIViewControllerRepresentable {

    let countries: [Country]
    var onCountryOpen: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> IndexedCountryListController {
        let listController = IndexedCountryListController(countries: countries)
        listController.onCountryOpen = onCountryOpen
        return listController
    }

    func updateUIViewController(_ uiViewController: IndexedCountryListController,
                                context: Context) {
        uiViewController.update(countries: countries)
    }
}
