import SwiftUI
import WidgetKit

@main
struct OrderlyWidgetBundle: WidgetBundle {
    init() {
        BundledFont.register()
    }

    var body: some Widget {
        CalendarWidget()
    }
}
