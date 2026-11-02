import SwiftUI
import WidgetKit

@main
struct OrderlyWidgetBundle: WidgetBundle {
    init() {
        DownloadableFonts.activate()
    }

    var body: some Widget {
        CalendarWidget()
    }
}
