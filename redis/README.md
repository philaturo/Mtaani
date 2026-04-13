# Mtaani - AI-Powered Responsible Tourism Platform for Kenya

Mtaani is a tourism platform that combines AI assistance, real-time safety monitoring, verified local businesses, and community-driven insights to help travelers discover and navigate Nairobi safely.

## Features

### Core Platform

- User authentication with phone verification
- Real-time social feed with posts and interactions
- AI travel assistant with conversation memory
- Interactive map with PostGIS geospatial data
- Emergency system with SOS and location sharing
- Dark and light mode support

### Social Features

- Create, view, and interact with posts
- Like, comment, repost, share, and bookmark with live counters
- Read receipts with delivery and read status
- Typing indicators in feed comments
- Online presence tracking

### AI Intelligence

- Conversation memory across sessions
- Nairobi knowledge base integration
- Semantic search for relevant information
- Personalized recommendations based on user preferences

### UI/UX

- Loading skeletons for content fetching
- Pull-to-refresh on mobile devices
- Optimistic updates for instant post creation
- Glassmorphic floating chat panel
- Infinite scroll pagination

### Technology Stack

- Backend: Elixir 1.19+, Phoenix 1.7.21, LiveView 1.0.18
- Database: PostgreSQL 18 with PostGIS 3.6
- Caching: Redis for read receipts and session management
- Vector Database: Pinecone for RAG memory
- AI: Groq API with Llama 3, HuggingFace embeddings
- Frontend: Tailwind CSS, MapLibre GL
- Maps: OpenStreetMap with PostGIS geospatial queries

## Prerequisites

- Elixir 1.19+ and Erlang/OTP 26+
- PostgreSQL 16+ with PostGIS
- Node.js 22+
- Redis
- Git

## Installation

Clone the repository:

````bash
git clone https://github.com/philaturo/Mtaani.git
cd Mtaani ```
````

Install Elixir dependencies:

```bash
mix deps.get
```

Install Node Dependancies

```bash
cd assets && npm install && cd ..
```

Configure your database in config/dev.exs with your PostgreSQL credentials. Create and migrate the database with PostGIS

```bash
mix ecto.create
mix ecto.migrate
psql -U postgres -d mtaani_dev -c "CREATE EXTENSION IF NOT EXISTS postgis;"
```

Start Redis (Windows):

```bash
cd redis && ./redis-server.exe
```

Start the Phoenix server:

```bash
mix phx.server
```

Visit http://localhost:4000 to see the application.

## Environment Variables

Create a .env file in the project root:

```bash
# Groq AI API Key (required)
GROQ_API_KEY=gsk_your_key_here

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Pinecone Vector DB (for RAG)
PINECONE_API_KEY=your_key_here
PINECONE_ENVIRONMENT=gcp-starter
PINECONE_INDEX=mtaani

# HuggingFace API (for embeddings)
HUGGINGFACE_API_KEY=hf_your_token_here
```

## Roadmap

### Completed features:

- User authentication
- Social feed with X-style interactions
- AI assistant with RAG and memory
- Real-time chat with read receipts
- Emergency safety features
- PostGIS geospatial data
- Glassmorphic UI with dark and light mode

### In progress:

- RAG knowledge base expansion
- Map enhancements

### Planned:

- Image and voice sharing
- Push notifications
- Trip planning
- WhatsApp integration
- Native mobile application
