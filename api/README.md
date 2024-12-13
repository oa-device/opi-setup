# OrangePi Device API

A FastAPI-based REST API for monitoring and managing OrangePi devices.

## Features

- System health monitoring
- Device metrics collection
- Player status tracking
- Screenshot capabilities
- Display information
- Deployment status

## Quick Start

1. Install dependencies:

```bash
pip install -r requirements.txt
```

2. Run the API:

```bash
uvicorn main:app --host 0.0.0.0 --port 9090
```

## API Documentation

The API documentation is automatically generated and available at:

- Swagger UI: `http://localhost:9090/docs`
- ReDoc: `http://localhost:9090/redoc`

## Core Endpoints

### Health Monitoring

- `GET /health` - Comprehensive system health status
- `GET /health/summary` - Health summary with recommendations

### Screenshots

- `GET /screenshots/latest` - Get the latest screenshot
- `GET /screenshots/history` - Get screenshot history
- `POST /screenshots/capture` - Capture a new screenshot

## Configuration

Key configurations can be found in `core/config.py`:

- Cache TTL settings
- Health score weights and thresholds
- Screenshot settings
- System paths and commands

## Project Structure

```tree
api/
├── core/           # Core configuration
├── models/         # Pydantic models
├── routers/        # API routes
├── services/       # Business logic
└── main.py        # Application entry point
```

## Health Scoring

The API provides health scores for various components:

- CPU utilization
- Memory usage
- Disk space
- Player status
- Display connection
- Network status

Overall health is calculated using weighted averages of these components.

## Caching

The API implements caching for expensive operations with configurable TTL (Time To Live) to optimize performance while maintaining data freshness.

## Error Handling

All endpoints include proper error handling and return appropriate HTTP status codes with descriptive error messages.

## Security

The API includes CORS middleware configuration. In production, make sure to:

1. Configure proper CORS origins
2. Set up authentication if needed
3. Use HTTPS
4. Follow security best practices
