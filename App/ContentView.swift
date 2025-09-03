import Core
import SwiftUI

struct ContentView: View {
    @State private var packageName: String = "Unknown"

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(packageName).padding()
            Button("Tap me") {
                print(Core.sayHello())
            }
            Button("Get package name") {
                packageName = Core.getName()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
