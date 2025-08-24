import { useState, useEffect } from 'react'
import './App.css'

interface Message {
  id: number
  text: string
  timestamp: string
}

// 백엔드 API URL 설정
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001'

function App() {
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)

  // 백엔드에서 메시지 가져오기
  const fetchMessages = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/messages`)
      const data = await response.json()
      setMessages(data)
    } catch (error) {
      console.error('메시지를 가져오는데 실패했습니다:', error)
    }
  }

  // 새 메시지 전송
  const sendMessage = async () => {
    if (!newMessage.trim()) return

    setLoading(true)
    try {
      const response = await fetch(`${API_BASE_URL}/api/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: newMessage }),
      })

      if (response.ok) {
        setNewMessage('')
        fetchMessages() // 메시지 목록 새로고침
      }
    } catch (error) {
      console.error('메시지 전송에 실패했습니다:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchMessages()
  }, [])

  return (
    <div className="app">
      <header className="app-header">
        <h1>🚀 AWS CI/CD 파이프라인 데모</h1>
        <p>React + NestJS + AWS EKS + RDS</p>
      </header>

      <main className="app-main">
        <div className="messages-container">
          <h2>메시지 목록</h2>
          {messages.length === 0 ? (
            <p className="no-messages">아직 메시지가 없습니다.</p>
          ) : (
            <div className="messages-list">
              {messages.map((message) => (
                <div key={message.id} className="message">
                  <p className="message-text">{message.text}</p>
                  <span className="message-time">
                    {new Date(message.timestamp).toLocaleString()}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="message-input">
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
            placeholder="메시지를 입력하세요..."
            disabled={loading}
          />
          <button onClick={sendMessage} disabled={loading || !newMessage.trim()}>
            {loading ? '전송 중...' : '전송'}
          </button>
        </div>
      </main>

      <footer className="app-footer">
        <p>GitHub Actions → Docker → AWS ECR → EKS → RDS</p>
      </footer>
    </div>
  )
}

export default App
