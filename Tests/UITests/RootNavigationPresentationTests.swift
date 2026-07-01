import Testing

@testable import UI

@Test
func rootNavigationUsesTheSelectedMenuItemTitleInTheHeader() {
  #expect(RootNavigationPresentation.defaultTopLevelDestination == .general)
  #expect(RootNavigationPresentation.title(for: .configuration) == "General")
  #expect(RootNavigationPresentation.title(for: .runtimeLog) == "Advanced")
  #expect(RootNavigationPresentation.defaultWindowTitle.isEmpty)
  #expect(!RootNavigationPresentation.syncsSelectedDestinationToWindowTitle)
  #expect(RootNavigationPresentation.usesHiddenTitleBar)
  #expect(!RootNavigationPresentation.showsVisualWindowTitle)
  #expect(RootNavigationPresentation.titleAlignment == .center)
  #expect(!RootNavigationPresentation.showsSeparatorBelowTitle)
  #expect(RootNavigationPresentation.windowTitle(for: .configuration).isEmpty)
  #expect(RootNavigationPresentation.windowTitle(for: .runtimeLog).isEmpty)
}

@Test
func rootNavigationKeepsTheRequiredMenuItemsAndIcons() {
  #expect(
    RootNavigationPresentation.menuItems.map(\.title) == ["General", "Advanced"]
  )
  #expect(
    RootNavigationPresentation.menuItems.map(\.systemImage) == ["gearshape", "slider.horizontal.3"]
  )
}

@Test
func rootNavigationUsesCompactMenuMetrics() {
  #expect(RootNavigationPresentation.menuTextSize <= 12)
  #expect(RootNavigationPresentation.menuIconSize >= 16)
  #expect(RootNavigationPresentation.menuIconSize <= 18)
  #expect(RootNavigationPresentation.menuItemVerticalPadding <= 8)
  #expect(RootNavigationPresentation.menuItemMaximumWidth <= 96)
  #expect(!RootNavigationPresentation.menuItemsUseOutlinedShape)
  #expect(!RootNavigationPresentation.menuItemsUseIconTile)
  #expect(RootNavigationPresentation.menuItemsUseSelectedBackground)
  #expect(!RootNavigationPresentation.menuSelectedBackgroundUsesAccentTint)
  #expect(RootNavigationPresentation.menuSelectedShadowOpacity > 0)
  #expect(RootNavigationPresentation.menuSelectedShadowRadius >= 8)
  #expect(RootNavigationPresentation.menuSelectedShadowYOffset >= 3)
  #expect(RootNavigationPresentation.menuItemCornerRadius <= 10)
}

@Test
func rootNavigationKeepsTheOriginalSidebarContentBelowTheTopMenu() {
  #expect(RootNavigationPresentation.showsSidebarBelowMenu)
  #expect(RootNavigationPresentation.showsSeparatorBelowMenu)
  #expect(
    RootNavigationPresentation.sidebarItems(for: .general).map(\.title) == ["Importer", "Exporter"]
  )
  #expect(RootNavigationPresentation.sidebarItems(for: .advanced).isEmpty)
}

@Test
func exporterSkeletonUsesDisabledProductionControls() {
  #expect(RootNavigationPresentation.exporterSkeletonTitle == "Exporter")
  #expect(RootNavigationPresentation.exporterSkeletonPrimaryControlTitle == "Execute")
  #expect(RootNavigationPresentation.exporterSkeletonSecondaryControlTitle == "Refresh")
  #expect(!RootNavigationPresentation.exporterSkeletonControlsAreEnabled)
}
