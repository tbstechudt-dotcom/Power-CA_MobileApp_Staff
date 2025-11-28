$headers = @{
    'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo'
    'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo'
    'Content-Type' = 'application/json'
    'Prefer' = 'return=representation'
}

$body = @'
[
  {
    "title": "Project Report Due",
    "description": "Complete and submit the quarterly project report to management. Include all milestones achieved and upcoming tasks.",
    "category": "due_date",
    "event_date": "2025-11-28T10:00:00Z",
    "author_id": "1",
    "author_name": "System Admin",
    "location": "Main Office"
  },
  {
    "title": "Client Presentation",
    "description": "Prepare slides and demo for the client presentation. Make sure all features are working properly.",
    "category": "due_date",
    "event_date": "2025-12-01T14:00:00Z",
    "author_id": "1",
    "author_name": "System Admin",
    "location": "Conference Room A"
  },
  {
    "title": "Team Meeting",
    "description": "Weekly team sync to discuss progress and blockers. All team members should attend.",
    "category": "meetings",
    "event_date": "2025-11-27T09:00:00Z",
    "author_id": "1",
    "author_name": "System Admin",
    "location": "Meeting Room 2"
  },
  {
    "title": "Happy Birthday John!",
    "description": "Wishing a wonderful birthday to our colleague John. Cake cutting at 3 PM!",
    "category": "greetings",
    "event_date": "2025-11-26T15:00:00Z",
    "author_id": "1",
    "author_name": "HR Team",
    "location": "Cafeteria"
  }
]
'@

Write-Host "Inserting demo pinboard items..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri 'https://jacqfogzgzvbjeizljqf.supabase.co/rest/v1/pinboard_items' -Method Post -Headers $headers -Body $body
    Write-Host "Successfully created demo items:" -ForegroundColor Green
    foreach ($item in $response) {
        Write-Host "  - $($item.title) ($($item.category))" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.Response.StatusCode
}
