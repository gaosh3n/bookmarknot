import Foundation
import Testing

@testable import Application

@Test
func configurationLayoutPersistsAcrossStoreReloads() throws {
  let suiteName = "ConfigurationLayoutStoreTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  defer {
    defaults.removePersistentDomain(forName: suiteName)
  }

  let store = ConfigurationLayoutStore(defaults: defaults)
  let layout = ConfigurationLayout(
    firstDividerPosition: 0.25,
    secondDividerPosition: 0.75,
    chrome: SourceArtifactTableLayout(
      showCreated: false,
      showCounts: true,
      showSize: false,
      showStatus: true,
      pathWidth: 400,
      createdWidth: 150,
      countsWidth: 170,
      sizeWidth: 130,
      statusWidth: 145
    ),
    safari: SourceArtifactTableLayout(
      showCreated: true,
      showCounts: false,
      showSize: true,
      showStatus: false,
      pathWidth: 360,
      createdWidth: 155,
      countsWidth: 165,
      sizeWidth: 135,
      statusWidth: 150
    ),
    bookmarknot: SavedArtifactTableLayout(
      showCreated: false,
      showCounts: true,
      showSize: false,
      hashWidth: 210,
      createdWidth: 180,
      countsWidth: 190,
      sizeWidth: 140
    )
  )

  let saved = store.save(layout)
  let reloaded = ConfigurationLayoutStore(defaults: defaults).load()

  #expect(reloaded == saved)
}

@Test
func invalidStoredValuesFallBackToUsableDefaults() throws {
  let suiteName = "ConfigurationLayoutStoreTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  defer {
    defaults.removePersistentDomain(forName: suiteName)
  }

  defaults.set(-1.0, forKey: "layout.firstDivider")
  defaults.set(2.0, forKey: "layout.secondDivider")
  defaults.set("wrong", forKey: "columns.chrome.created")
  defaults.set(-40.0, forKey: "columns.chrome.pathWidth")
  defaults.set(90.0, forKey: "columns.bookmarknot.hashWidth")

  let layout = ConfigurationLayoutStore(defaults: defaults).load()

  #expect(layout.firstDividerPosition == ConfigurationLayout.default.firstDividerPosition)
  #expect(layout.secondDividerPosition == ConfigurationLayout.default.secondDividerPosition)
  #expect(layout.chrome.showCreated == SourceArtifactTableLayout.default.showCreated)
  #expect(layout.chrome.pathWidth == SourceArtifactTableLayout.default.pathWidth)
  #expect(layout.bookmarknot.hashWidth == SavedArtifactTableLayout.default.hashWidth)
  #expect(layout.chrome.showCounts == SourceArtifactTableLayout.default.showCounts)
  #expect(layout.safari == SourceArtifactTableLayout.default)
  #expect(layout.bookmarknot.showCreated == SavedArtifactTableLayout.default.showCreated)
}

@Test
func invalidStoredValuesDoNotDiscardOtherValidPreferences() throws {
  let suiteName = "ConfigurationLayoutStoreTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  defer {
    defaults.removePersistentDomain(forName: suiteName)
  }

  defaults.set(0.2, forKey: "layout.firstDivider")
  defaults.set(0.25, forKey: "layout.secondDivider")
  defaults.set(false, forKey: "columns.chrome.created")
  defaults.set(420.0, forKey: "columns.chrome.pathWidth")
  defaults.set(-40.0, forKey: "columns.chrome.countsWidth")
  defaults.set(false, forKey: "columns.bookmarknot.size")
  defaults.set(200.0, forKey: "columns.bookmarknot.hashWidth")

  let layout = ConfigurationLayoutStore(defaults: defaults).load()

  #expect(layout.firstDividerPosition == 0.2)
  #expect(layout.secondDividerPosition == 0.25)
  #expect(layout.chrome.showCreated == false)
  #expect(layout.chrome.pathWidth == 420.0)
  #expect(layout.chrome.countsWidth == SourceArtifactTableLayout.default.countsWidth)
  #expect(layout.bookmarknot.showSize == false)
  #expect(layout.bookmarknot.hashWidth == 200.0)
}

@Test
func invalidStoredDividerOrderFallsBackToDefaultSectionHeights() throws {
  let suiteName = "ConfigurationLayoutStoreTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  defer {
    defaults.removePersistentDomain(forName: suiteName)
  }

  defaults.set(0.7, forKey: "layout.firstDivider")
  defaults.set(0.6, forKey: "layout.secondDivider")
  defaults.set(false, forKey: "columns.chrome.created")
  defaults.set(420.0, forKey: "columns.chrome.pathWidth")

  let layout = ConfigurationLayoutStore(defaults: defaults).load()

  #expect(layout.firstDividerPosition == ConfigurationLayout.default.firstDividerPosition)
  #expect(layout.secondDividerPosition == ConfigurationLayout.default.secondDividerPosition)
  #expect(layout.chrome.showCreated == false)
  #expect(layout.chrome.pathWidth == 420.0)
}

@Test
func identityColumnsRemainVisibleWhenOptionalColumnsAreHidden() throws {
  let layout = ConfigurationLayout(
    firstDividerPosition: ConfigurationLayout.default.firstDividerPosition,
    secondDividerPosition: ConfigurationLayout.default.secondDividerPosition,
    chrome: SourceArtifactTableLayout(
      showCreated: false,
      showCounts: false,
      showSize: false,
      showStatus: false,
      pathWidth: 320,
      createdWidth: 145,
      countsWidth: 140,
      sizeWidth: 120,
      statusWidth: 120
    ),
    safari: SourceArtifactTableLayout(
      showCreated: false,
      showCounts: false,
      showSize: false,
      showStatus: false,
      pathWidth: 320,
      createdWidth: 145,
      countsWidth: 140,
      sizeWidth: 120,
      statusWidth: 120
    ),
    bookmarknot: SavedArtifactTableLayout(
      showCreated: false,
      showCounts: false,
      showSize: false,
      hashWidth: 150,
      createdWidth: 160,
      countsWidth: 140,
      sizeWidth: 120
    )
  )

  #expect(layout.chrome.visibleColumns == [.path])
  #expect(layout.safari.visibleColumns == [.path])
  #expect(layout.bookmarknot.visibleColumns == [.shortHash])
}

@Test
func defaultColumnWidthsUseTheSharedMinimumAcrossAllArtifactTables() {
  #expect(SourceArtifactTableLayout.default.pathWidth == 120)
  #expect(SourceArtifactTableLayout.default.createdWidth == 120)
  #expect(SourceArtifactTableLayout.default.countsWidth == 120)
  #expect(SourceArtifactTableLayout.default.sizeWidth == 120)
  #expect(SourceArtifactTableLayout.default.statusWidth == 120)
  #expect(SavedArtifactTableLayout.default.hashWidth == 120)
  #expect(SavedArtifactTableLayout.default.createdWidth == 120)
  #expect(SavedArtifactTableLayout.default.countsWidth == 120)
  #expect(SavedArtifactTableLayout.default.sizeWidth == 120)
}
