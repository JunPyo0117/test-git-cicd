import { useState, useEffect } from 'react'
import './App.css'
import GoogleMap from './components/GoogleMap'

interface Message {
  id: number
  text: string
  timestamp: string
}

// 백엔드 API URL 설정
const API_BASE_URL = import.meta.env.VITE_API_URL || '/api'
// 구글 맵스 API 키 설정
const GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || ''

// 서울 주요 관광지 순차 방문 경로 (정확한 좌표로 업데이트)
const SEOUL_WAYPOINTS = [
  { lat: 37.5665, lng: 126.9780, title: '서울 시청' },
  { lat: 37.5796, lng: 126.9770, title: '경복궁' },
  { lat: 37.5139, lng: 127.0606, title: '강남역' },
  { lat: 37.5519, lng: 126.9882, title: '명동' },
  { lat: 37.5716, lng: 126.9764, title: '광화문' }
];

function App() {
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(false)
  const [showRoute, setShowRoute] = useState(false)

  // 백엔드에서 메시지 가져오기
  const fetchMessages = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/messages`)
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
      const response = await fetch(`${API_BASE_URL}/messages`, {
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
        <h1>🚀 AWS CI/CD 파이프라인 데모 테스트</h1>
        <p>React + NestJS + AWS EKS + RDS + Google Maps</p>
      </header>

      <main className="app-main">
        {/* 구글 지도 섹션 */}
        <div className="map-section">
          <h2>📍 구글 지도</h2>
          <div className="map-controls">
            <button 
              onClick={() => setShowRoute(!showRoute)}
              className="route-toggle-btn"
            >
              {showRoute ? '단일 지점 보기' : '서울 관광지 경로 보기'}
            </button>
          </div>
          {GOOGLE_MAPS_API_KEY ? (
            <GoogleMap 
              apiKey={GOOGLE_MAPS_API_KEY}
              center={{ lat: 37.5665, lng: 126.9780 }} // 서울 시청
              zoom={showRoute ? 10 : 13}
              style={{ width: '100%', height: '600px', marginBottom: '20px' }}
              waypoints={showRoute ? SEOUL_WAYPOINTS : []}
            />
          ) : (
            <div className="map-placeholder">
              <p>⚠️ Google Maps API 키가 설정되지 않았습니다.</p>
              <p>환경변수 VITE_GOOGLE_MAPS_API_KEY를 설정해주세요.</p>
            </div>
          )}
                      {showRoute && (
              <div className="route-info">
                <h3>🚇 서울 대중교통 경로 (5개 지점)</h3>
                              <p style={{ marginBottom: '10px', color: '#666' }}>
                🚇 대중교통(지하철/버스) 기준으로 순차 경로를 표시합니다.
                <br />
                ✨ <strong>최단 경로 알고리즘</strong>이 적용되어 가까운 곳끼리 묶어서 효율적인 경로를 제공합니다.
              </p>
              <ol>
                {SEOUL_WAYPOINTS.map((point: any, index: number) => (
                  <li key={index} style={{ marginBottom: '8px' }}>
                    <strong>{index + 1}. {point.title}</strong>
                    <span className="coordinates">
                      ({point.lat.toFixed(4)}, {point.lng.toFixed(4)})
                    </span>
                    {index < SEOUL_WAYPOINTS.length - 1 && (
                      <span style={{ color: '#888', marginLeft: '10px' }}>
                        🚇 다음: {SEOUL_WAYPOINTS[index + 1].title}
                      </span>
                    )}
                  </li>
                ))}
              </ol>
              <p className="route-note">
                🚇 기본 모드: 대중교통 (지하철/전철/버스)
                <br />
                🎨 각 구간이 서로 다른 색상으로 표시되어 경로를 쉽게 구분할 수 있습니다.
                <br />
                🔄 다른 모드: 🚗 자동차, 🚶 도보, 🚲 자전거로 변경 가능합니다.
                <br />
                ⚡ 대중교통 정보가 없는 경우 자동으로 다른 모드로 재시도합니다.
              </p>
            </div>
          )}
        </div>

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
