//
//  WelcomeScreen.swift
//  Layman
//
//  Created by Pankaj Kumar Rana on 01/04/26.
//

import SwiftUI

struct WelcomeScreen: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showAuthFlow = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(#colorLiteral(red: 0.98, green: 0.86, blue: 0.78, alpha: 1)),
                        Color(#colorLiteral(red: 0.95, green: 0.75, blue: 0.60, alpha: 1))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    // Top Title
                    Text("Layman")
                        .font(.system(size: 50, weight: .semibold))
                        .padding(.top, 40)

                    Spacer()

                    // Main Text
                    VStack(spacing: 4) {
                        Text("Business,")
                        Text("tech & startups")

                        Text("made simple")
                            .foregroundStyle(.orange)
                    }
                    .font(.system(size: 40, weight: .bold))
                    .multilineTextAlignment(.center)

                    Spacer()

                    // Swipe Button
                    SwipeButton {
                        showAuthFlow = true
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(isPresented: $showAuthFlow) {
                AuthScreen(viewModel: authViewModel)
            }
        }
    }
}



struct SwipeButton: View {
    var action: () -> Void
    
    @State private var offset: CGFloat = 0
    
    let buttonWidth: CGFloat = 300
    let handleSize: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 30)
                .fill(.button)
                .frame(height: 60)
            
            // Text
            Text("Swipe to get started")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            
            // Draggable Circle
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: handleSize, height: handleSize)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.orange)
                   

                }
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                offset = min(value.translation.width, buttonWidth - handleSize)
                            }
                        }
                        .onEnded { _ in
                            if offset > (buttonWidth - handleSize) * 0.7 {
                                // Complete swipe
                                withAnimation {
                                    offset = buttonWidth - handleSize
                                    
                                }
                                
                                // Trigger action
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    action()
                                }
                            } else {
                                // Reset
                                withAnimation {
                                    offset = 0
                                }
                            }
                        }
                )
                
                Spacer()
            }
            .padding(.leading, 5)
        }
        .frame(width: buttonWidth)
    }
}

#Preview {
    WelcomeScreen(authViewModel: AuthViewModel())
    
}
