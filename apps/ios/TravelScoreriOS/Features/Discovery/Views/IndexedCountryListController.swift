//
//  IndexedCountryListController.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/1/26.
//

import UIKit
import SwiftUI

final class IndexedCountryListController: UITableViewController {

    private var countries: [Country] = []
    private var grouped: [String: [Country]] = [:]
    private var sortedKeys: [String] = []

    init(countries: [Country]) {
        self.countries = countries
        super.init(style: .plain)
        regroup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(countries: [Country]) {
        self.countries = countries
        regroup()
        tableView.reloadData()
    }

    private func regroup() {
        grouped = Dictionary(grouping: countries) {
            String($0.name.prefix(1)).uppercased()
        }
        sortedKeys = grouped.keys.sorted()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        tableView.sectionIndexColor = .secondaryLabel
        tableView.sectionIndexBackgroundColor = .clear

        tableView.sectionIndexTrackingBackgroundColor = .clear
        tableView.sectionIndexMinimumDisplayRowCount = 1

        tableView.allowsSelection = true
    }

    // MARK: Sections

    override func numberOfSections(in tableView: UITableView) -> Int {
        sortedKeys.count
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        grouped[sortedKeys[section]]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView,
                            titleForHeaderInSection section: Int) -> String? {
        sortedKeys[section]
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sortedKeys
    }

    override func tableView(_ tableView: UITableView,
                            sectionForSectionIndexTitle title: String,
                            at index: Int) -> Int {
        index
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell",
                                                 for: indexPath)

        let country = grouped[sortedKeys[indexPath.section]]![indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = "\(country.flagEmoji)  \(country.name)"
        content.secondaryText = nil
        cell.contentConfiguration = content

        if let score = country.score {
            let scoreLabel = PaddingLabel()
            scoreLabel.text = "\(score)"
            scoreLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            scoreLabel.textColor = .label

            let bgColor: UIColor
            switch score {
            case 80...100:
                bgColor = UIColor.systemGreen.withAlphaComponent(0.18)
            case 60..<80:
                bgColor = UIColor.systemYellow.withAlphaComponent(0.22)
            default:
                bgColor = UIColor.systemRed.withAlphaComponent(0.18)
            }

            scoreLabel.backgroundColor = bgColor
            scoreLabel.layer.cornerRadius = 14
            scoreLabel.layer.masksToBounds = true
            scoreLabel.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            scoreLabel.sizeToFit()
            let intrinsicWidth = scoreLabel.intrinsicContentSize.width
            scoreLabel.frame = CGRect(x: 0, y: 0, width: intrinsicWidth, height: 24)

            cell.accessoryView = scoreLabel
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        let sectionKey = sortedKeys[indexPath.section]
        guard let country = grouped[sectionKey]?[indexPath.row] else { return }

        tableView.deselectRow(at: indexPath, animated: true)

        let hostingController = UIHostingController(
            rootView: CountryDetailView(country: country)
        )
        hostingController.title = country.name

        navigationController?.pushViewController(hostingController, animated: true)
    }
}

final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
