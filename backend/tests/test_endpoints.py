from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
import main

client = TestClient(main.app)


def make_mock_groq(content: str):
    mock = MagicMock()
    mock.chat.completions.create.return_value.choices[0].message.content = content
    return mock


def test_chat_normal_message():
    with patch.object(main, "client", make_mock_groq("I hear you. Let's work through this together.")):
        response = client.post("/chat", json={
            "patientMessage": "I've been feeling anxious and overwhelmed lately.",
            "conversationHistory": [],
            "messageCount": 0
        })
    assert response.status_code == 200
    assert "response" in response.json()


def test_red_flag_crisis_message():
    with patch.object(main, "client", make_mock_groq('{"isRedFlag": true, "severity": "critical"}')):
        response = client.post("/red-flag", json={
            "patientMessage": "I don't want to live anymore."
        })
    assert response.status_code == 200
    data = response.json()
    assert "isRedFlag" in data
    assert "severity" in data


def test_red_flag_normal_message():
    with patch.object(main, "client", make_mock_groq('{"isRedFlag": false, "severity": "none"}')):
        response = client.post("/red-flag", json={
            "patientMessage": "I've been stressed about work lately."
        })
    assert response.status_code == 200
    assert "severity" in response.json()


def test_patient_summary():
    with patch.object(main, "client", make_mock_groq("Patient presents with moderate depression and anxiety symptoms.")):
        response = client.post("/patient-summary", json={
            "assessmentText": "Patient reports sadness, loss of interest, and difficulty sleeping.",
            "description": "PHQ-9 score: 18"
        })
    assert response.status_code == 200
    assert "summary" in response.json()


def test_emotional_support_welcome():
    with patch.object(main, "client", make_mock_groq("Welcome! I'm here to support you.")):
        response = client.post("/emotional-support", json={
            "type": "welcome",
            "patientText": "I just joined and feeling nervous."
        })
    assert response.status_code == 200
    assert "response" in response.json()
