//
//  ContentView.swift
//  CityWeaver
//
//  Created by Jan Stusio on 29/08/2025.
//

import Core
import RoadGenAlg
import Shared
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("Tap me") {
                print(Core.sayHello())
                print(Shared.sayHello())
                RoadGenAlg.exampleUsage()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
