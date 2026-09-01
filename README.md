## GitHub Repository Description

**SmartSpend — A modern Flutter-based personal expense manager with secure Firebase authentication, cloud-synced expense tracking, financial insights, receipt OCR, local notifications, and a personalized user experience.**

---

# README.md

````markdown
# SmartSpend

<p align="center">
  <img src="assets/images/logo.png" width="140" alt="SmartSpend Logo">
</p>

<h3 align="center">Smart money tracking, made simple.</h3>

<p align="center">
  A modern personal expense management application built with Flutter and Firebase.
</p>

---

## About SmartSpend

**SmartSpend** is a personal finance management application designed to make everyday expense tracking simple, organized, and insightful.

Instead of simply recording numbers, SmartSpend helps users understand their spending through categorized expenses, visual insights, receipt-based OCR, and useful notifications.

The application was built as a personal project with a focus on **clean UI, practical functionality, secure data management, and a smooth mobile experience**.

---

## ✨ Features

### 🔐 Authentication
- User account creation
- Secure sign-in
- Logout
- Authentication state management
- Account deletion

### 💰 Expense Management
- Add expenses quickly
- Edit existing expenses
- Delete expenses
- Categorize expenses
- View expense history
- Indian Rupee (₹) support

### 📊 Financial Insights
- Spending summaries
- Category-based expense analysis
- Visual charts
- Spending pattern visualization

### 📷 Receipt OCR
SmartSpend uses **Google ML Kit Text Recognition** to assist with receipt-based expense entry.

```text
Receipt
   ↓
Capture / Select Image
   ↓
Google ML Kit
   ↓
Text Recognition
   ↓
Extracted Text
   ↓
Expense Information
   ↓
User Verification
````

This reduces the amount of information users need to enter manually.

### 🔔 Notifications

SmartSpend uses local Android notifications for supported financial insights, reminders, and application events.

Notifications are delivered through the device's notification system.

### 👤 Profile & Settings

* Personalized user profile
* Profile picture
* Application settings
* Notification preferences
* Account management

### 🚀 Branded Startup Experience

SmartSpend features a two-stage startup experience:

**Company Branding → SmartSpend Logo → Application**

This separates the company identity from the application identity.

---

# 🏗️ Architecture

SmartSpend follows a layered application architecture.

```text
                         USER
                           │
                           ▼
                ┌─────────────────────┐
                │   PRESENTATION      │
                │       LAYER         │
                │                     │
                │ Login               │
                │ Dashboard           │
                │ Add Expense         │
                │ Expense History      │
                │ Insights             │
                │ Profile / Settings   │
                └──────────┬──────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │   STATE MANAGEMENT  │
                │      Riverpod       │
                └──────────┬──────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │  APPLICATION LOGIC  │
                │                     │
                │ Expense Management  │
                │ Insights            │
                │ OCR Processing      │
                │ Notifications       │
                │ Account Management  │
                └──────────┬──────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
   ┌──────────────────┐        ┌──────────────────┐
   │  LOCAL SERVICES  │        │     FIREBASE     │
   │                  │        │                  │
   │ Image Handling   │        │ Authentication   │
   │ ML Kit OCR       │        │ Cloud Firestore  │
   │ Notifications    │        │                  │
   └──────────────────┘        └──────────────────┘
```

---

# ☁️ Cloud Architecture

SmartSpend uses Firebase as its cloud backend.

```text
                    SmartSpend
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
      Firebase Auth           Cloud Firestore
             │                       │
             │ UID                   │
             └───────────┬───────────┘
                         ▼
                       users
                         │
                      {userId}
                     /        \
                    /          \
                   ▼            ▼
              expenses       settings
```

Firebase Authentication manages user identity, while Cloud Firestore stores user-specific application data.

Firestore security rules restrict access to authenticated users' own data.

---

# 🗄️ Database Structure

```text
users
└── {userId}
    ├── expenses
    │   └── {expenseId}
    │
    └── settings
        └── {documentId}
```

Each user's application data is associated with their Firebase Authentication UID.

### Security principle

```text
Authenticated User
        │
        ▼
request.auth.uid
        │
        ▼
Compare with userId
     /       \
  Match     No Match
    │           │
  Allow        Deny
```

This helps prevent users from accessing another user's expense or settings data.

---

# 🛠️ Technology Stack

| Technology                  | Purpose                      |
| --------------------------- | ---------------------------- |
| Flutter                     | Mobile application framework |
| Dart                        | Programming language         |
| Riverpod                    | State management             |
| GoRouter                    | Application navigation       |
| Firebase Authentication     | User authentication          |
| Cloud Firestore             | Cloud database               |
| Google ML Kit               | Receipt text recognition     |
| Flutter Local Notifications | Local notifications          |
| fl_chart                    | Financial visualization      |
| Gradle                      | Android build system         |

---

# 📱 Application Flow

```text
                    App Launch
                        │
                        ▼
                 Company Branding
                        │
                        ▼
                  SmartSpend Logo
                        │
                        ▼
                  Authentication
                   /           \
                  /             \
          Create Account        Login
                  \             /
                   \           /
                     Dashboard
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
     Add Expense     Expense History   Insights
          │              │              │
          └──────────────┼──────────────┘
                         │
                         ▼
                  Profile / Settings
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        Notifications          Account
                               Management
                                   │
                                   ▼
                             Delete Account
```

---

# 🔒 Security

SmartSpend uses Firebase Authentication and Cloud Firestore security rules to protect user-specific information.

The security model ensures that:

* Authentication is required for protected data.
* Users can access their own expense records.
* Users can access their own settings.
* Users cannot directly access another user's data.
* Unauthenticated access is denied.

---

# 🧪 Testing

The application was tested across major functional areas including:

* Account creation
* Authentication
* Login/logout
* Expense creation
* Expense editing
* Expense deletion
* Expense history
* OCR processing
* Financial insights
* Notifications
* Notification permissions
* Profile management
* Account deletion
* Firebase data access
* Android release builds
* Physical Android device testing

---

# ⚡ Performance

Performance improvements focused on maintaining the existing architecture while making the application feel more responsive.

Considerations included:

* Efficient state updates
* Avoiding unnecessary widget rebuilds
* Minimizing unnecessary database operations
* Efficient image handling
* Asynchronous operations
* Reducing unnecessary startup work

---

# 🎯 Project Goals

SmartSpend was built with four main principles:

**Simple**
Make recording an expense quick and straightforward.

**Secure**
Keep user-specific financial information protected.

**Insightful**
Turn expense records into information users can actually understand.

**Practical**
Build something that can be used as a real everyday application rather than only as a demonstration project.

---

# 🚀 Future Improvements

Potential future enhancements include:

* Advanced budgeting
* Recurring expenses
* More detailed financial reports
* Improved receipt information extraction
* Advanced spending analytics
* More customizable notifications
* Financial recommendations
* Additional export options
* Multi-device improvements

---

# 📌 Project Status

**Status: Completed Personal Project**

SmartSpend has been developed, tested, and packaged as an Android application.

The project continues to serve as a practical demonstration of Flutter development, Firebase integration, mobile UI/UX design, cloud data management, OCR integration, notification handling, and Android deployment.

---

# 👨‍💻 Developer

**Sathiyamurthy**

Personal project developed using Flutter, Dart, Firebase, and Google ML Kit.

