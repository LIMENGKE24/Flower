<div align="center">
  <img src="./flower/Assets.xcassets/FLOWERLOGO.imageset/ChatGPT%20Image%20Sep%2012,%202025,%2004_37_34%20PM.png" alt="Flower App Logo" width="200"/>
  
  # Flower
  
  **Keep Your Love Fresh**
  
  A shared virtual gardening experience for couples.
  
  [![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-2.0+-blue.svg)](https://developer.apple.com/xcode/swiftui/)
  [![Firebase](https://img.shields.io/badge/Firebase-Supported-yellow.svg)](https://firebase.google.com/)
</div>

## 📖 Overview

**Flower** is a heartwarming iOS application designed for couples to jointly care for a virtual flower. It serves as a gentle reminder of connection and care. The flower reflects the attention it receives—staying fresh when watered and withering if neglected, symbolizing the constant nurturing required in a relationship.

## ✨ Features

- **Shared Garden**: Both partners can view and interact with the same flower in real-time.
- **Dynamic States**:
  - 🌹 **Fresh**: The flower is happy and blooming.
  - 🥀 **Withered**: If not watered for **4 hours**, the flower turns "bad".
- **Watering Mechanism**: A simple tap waters the flower, restoring it to its fresh state immediately.
- **Live Updates**: Backend integration ensures that when one partner waters the flower, the other sees the change instantly.
- **User Status**: Tracks user online presence.

## 🛠 Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Backend**: Firebase (Auth, Firestore/Realtime Database)
- **Architecture**: MVVM

## 🚀 Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 16.0 or later
- A Firebase project setup

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/LIMENGKE24/flower.git
    cd flower
    ```

2.  **Setup Firebase**
    - Create a project in the [Firebase Console](https://console.firebase.google.com/).
    - Download the `GoogleService-Info.plist` file.
    - Place `GoogleService-Info.plist` in the root of the project (same level as `flowerApp.swift`).
    *Note: This file is git-ignored to protect your credentials.*

3.  **Open the Project**
    - Open `flower.xcodeproj` in Xcode.

4.  **Build and Run**
    - Select your target simulator or device.
    - Press `Cmd + R` to build and run.

## 📱 Usage

1.  **Sign Up/Login**: Create an account to connect with your partner.
2.  **Check the Flower**: Open the app to see the current state of your flower.
3.  **Water It**: If the flower is withered (or just to show love), tap the water button.
4.  **Stay Connected**: Keep the flower fresh together!

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is created by [Mengke Li](https://github.com/LIMENGKE24). All rights reserved.
