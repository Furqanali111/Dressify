# Dressify

Dressify is an AI-powered personal stylist and virtual wardrobe application. It helps users manage their clothing items, generate outfits using LLMs (OpenAI/Ollama), and get real-time fashion feedback based on their wardrobe and the local weather.

## 🚀 Key Features

*   **Virtual Wardrobe**: Upload and manage clothing items with AI-powered background removal and categorization.
*   **AI Outfit Generation**: Get personalized outfit suggestions for any occasion, optimized for your body type and current weather.
*   **AI Style Report**: Real-time feedback on your looks, analyzing color harmony, silhouette balance, and occasion fit.
*   **Virtual Try-On**: Preview outfits on a customizable 2D avatar.
*   **Wardrobe Analytics**: Track your wear history, identify underutilized items, and see your wardrobe's color/style distribution.
*   **Smart Notifications**: Get reminded to log your wear or alerted when new style tips are available.

## 🛠️ Tech Stack

### Backend
*   **Framework**: FastAPI (Python 3.11+)
*   **Database**: PostgreSQL with SQLAlchemy (Async)
*   **Authentication**: Supabase Auth (Google OAuth)
*   **Storage**: Supabase Storage
*   **AI/ML**: OpenAI GPT-4o / Ollama (Llama 3.2 Vision)
*   **Background Jobs**: Built-in retry worker for failed image uploads

### Frontend
*   **Framework**: Flutter
*   **State Management**: Riverpod
*   **Navigation**: GoRouter
*   **Styling**: Custom Design System (Vanilla CSS inspired components)
*   **Local Storage**: Flutter Secure Storage

## 📦 Project Structure

```text
├── Backend/                # FastAPI application
│   ├── app/
│   │   ├── core/           # Config, Security, Rate Limiting
│   │   ├── models/         # SQLAlchemy ORM Models
│   │   ├── routers/        # API Endpoints
│   │   ├── schemas/        # Pydantic Models
│   │   └── services/       # AI, Weather, Storage logic
│   └── alembic/            # Database migrations
├── Frontend/               # Flutter mobile application
│   ├── lib/
│   │   ├── core/           # Providers, Themes, Models, Router
│   │   └── features/       # Feature-based UI modules
│   └── assets/             # Icons and Images
└── Doc/                    # Improvement logs and Roadmap
```

## 🛠️ Setup & Installation

### Backend
1. `cd Backend`
2. `pip install -r requirements.txt`
3. Create a `.env` file based on the config requirements (Supabase, OpenAI, etc.)
4. `alembic upgrade head`
5. `uvicorn app.main:app --reload`

### Frontend
1. `cd Frontend`
2. `flutter pub get`
3. Configure API base URL in `lib/core/api/api_client.dart`
4. `flutter run`

## 📜 Development Logs
Detailed improvement logs can be found in the [Doc/](Doc/) directory, specifically `improvements_6.md` for the latest production readiness updates.
