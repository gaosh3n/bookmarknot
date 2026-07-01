import Foundation

enum RootNavigationTitleAlignment {
  case center
}

enum RootDestination: String, CaseIterable, Hashable, Identifiable {
  case configuration
  case runtimeLog

  var id: String { rawValue }
}

enum RootTopLevelDestination: String, CaseIterable, Hashable, Identifiable {
  case general
  case advanced

  var id: String { rawValue }
}

enum RootSidebarDestination: String, CaseIterable, Hashable, Identifiable {
  case importer
  case exporter

  var id: String { rawValue }
}

struct RootNavigationItem: Equatable {
  let destination: RootDestination
  let topLevelDestination: RootTopLevelDestination
  let title: String
  let systemImage: String
}

struct RootSidebarItem: Equatable {
  let destination: RootSidebarDestination
  let title: String
  let systemImage: String
}

enum RootNavigationPresentation {
  static let defaultTopLevelDestination = RootTopLevelDestination.general
  static let defaultSidebarDestination = RootSidebarDestination.importer
  static let defaultWindowTitle = ""
  static let syncsSelectedDestinationToWindowTitle = false
  static let usesHiddenTitleBar = true
  static let showsVisualWindowTitle = false
  static let titleAlignment = RootNavigationTitleAlignment.center
  static let showsSeparatorBelowTitle = false
  static let menuTextSize = 12.0
  static let menuIconSize = 16.0
  static let menuItemVerticalPadding = 8.0
  static let menuItemHorizontalPadding = 12.0
  static let menuItemSpacing = 6.0
  static let menuItemMaximumWidth = 92.0
  static let menuItemsUseOutlinedShape = false
  static let menuItemsUseIconTile = false
  static let menuItemsUseSelectedBackground = true
  static let menuSelectedBackgroundUsesAccentTint = false
  static let menuSelectedShadowOpacity = 0.14
  static let menuSelectedShadowRadius = 10.0
  static let menuSelectedShadowYOffset = 4.0
  static let menuItemCornerRadius = 8.0
  static let topPadding = 10.0
  static let titleBottomPadding = 8.0
  static let menuTopPadding = 4.0
  static let menuBottomPadding = 12.0
  static let showsSidebarBelowMenu = true
  static let showsSeparatorBelowMenu = true
  static let exporterSkeletonTitle = "Exporter"
  static let exporterSkeletonPrimaryControlTitle = "Execute"
  static let exporterSkeletonSecondaryControlTitle = "Refresh"
  static let exporterSkeletonControlsAreEnabled = false
  static let menuItems = makeMenuItems()

  static func title(for destination: RootDestination) -> String {
    item(for: destination).title
  }

  static func windowTitle(for destination: RootDestination) -> String {
    syncsSelectedDestinationToWindowTitle ? title(for: destination) : defaultWindowTitle
  }

  static func topLevelDestination(for destination: RootDestination) -> RootTopLevelDestination {
    item(for: destination).topLevelDestination
  }

  static func sidebarItems(for destination: RootTopLevelDestination) -> [RootSidebarItem] {
    switch destination {
    case .general:
      makeGeneralSidebarItems()
    case .advanced:
      []
    }
  }

  static func item(for destination: RootDestination) -> RootNavigationItem {
    guard let item = menuItems.first(where: { $0.destination == destination }) else {
      fatalError("Missing navigation item for \(destination)")
    }
    return item
  }

  private static func makeMenuItems() -> [RootNavigationItem] {
    var items: [RootNavigationItem] = []
    items.append(
      RootNavigationItem(
        destination: .configuration,
        topLevelDestination: .general,
        title: "General",
        systemImage: "gearshape"
      )
    )
    items.append(
      RootNavigationItem(
        destination: .runtimeLog,
        topLevelDestination: .advanced,
        title: "Advanced",
        systemImage: "slider.horizontal.3"
      )
    )
    return items
  }

  private static func makeGeneralSidebarItems() -> [RootSidebarItem] {
    var items: [RootSidebarItem] = []
    items.append(
      RootSidebarItem(
        destination: .importer,
        title: "Importer",
        systemImage: "square.and.arrow.down"
      )
    )
    items.append(
      RootSidebarItem(
        destination: .exporter,
        title: "Exporter",
        systemImage: "square.and.arrow.up"
      )
    )
    return items
  }
}
