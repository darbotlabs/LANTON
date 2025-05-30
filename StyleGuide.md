# LANton – Style Guide

This document outlines the design principles, colors, layout, and typography used in LANton's user interface.

## 🎨 Color Palette

| Element          | Color Code | Description                                 |
| ---------------- | ---------- | ------------------------------------------- |
| Background       | #1a1a1a  | Dark background for main content            |
| Panel Background | #252525  | Slightly lighter background for panels      |
| Primary Text     | #e0e0e0  | Light gray for primary text content         |
| Secondary Text   | #a0a0a0  | Medium gray for secondary information       |
| Primary Accent   | #00aaff  | Bright blue for headers and active elements |
| Secondary Accent | #0055aa  | Darker blue for borders and highlights      |
| Status Green     | #00ff00  | Bright green for terminal and success       |
| Status Yellow    | #ffaa00  | Amber for warnings                          |
| Status Red       | #ff0000  | Red for errors and stop indicators          |
| Terminal BG      | #000000  | Black for terminal background               |

## 📏 Layout Guidelines

### Header
- Compact height (reduced by ~50%)
- Padding:  .4rem 1rem 0.4rem 1rem
- System info displayed inline directly below header
- System info uses tab indentation (2.5em) with green text

### Navigation
- Tab-based design with active tab highlighted
- Border-bottom indicator for selected tab

### Content Panels
- Card-based layout for services and main content
- Clean spacing with consistent padding (1rem)
- Status indicators use colored dots

### Terminal Elements
- Font: Consolas monospace
- Text color: Bright green (#00ff00)
- Black background (#000000)

## 🖋 Typography

- **Primary Font**: Consolas monospace throughout the interface
- **Header Size**: 2rem for main headers
- **System Info**: 0.95rem with green coloring
- **Line Height**: 1.6 for content, 1.1 for headers

## 💻 UI Components

### System Information
- Format: Node: [hostname]; [IP address]
- Color: Match terminal green
- Position: Directly below main header with minimal vertical space

### Status Indicators
- Green dot with glow effect for running services
- Red dot for stopped services

### Buttons
- Blue background (#0055aa)
- No border, 0.5rem padding
- Hover effect: lighter blue (#00aaff)
- Border-radius: 3px

### Terminal Windows
- Height: 400px with scrolling
- Pre-wrapped text formatting
- Command input at bottom

## 📜 License

MIT © Darbot Labs

---

*Built with ♥ by the Darbot Council. May your ports never clash!*
