# Copilot Instructions for Flower App

## Project Overview
This is an iOS application built with SwiftUI for a couple (the user and their wife) to virtually water a flower.

## Core Logic
- **Flower State**: The flower has two states: "fresh" and "bad" (withered).
- **Watering Logic**: 
  - If the flower is not watered for 4 hours, it turns "bad".
  - Watering the flower makes it "fresh" again.
- **Backend**: There is a backend server that records user online status and likely manages the flower's state and watering timestamps.

## Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Backend Integration**: The app communicates with a backend server.

## Coding Style
- Use functional SwiftUI patterns.
- Ensure thread safety when updating UI from network responses.
- Handle network errors gracefully.
