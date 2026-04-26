import { useEffect, useMemo, useState } from 'react';
import type { ArcadeCatalog, ArcadeGame, Challenge, LeaderboardEntry, Player, ScoreSubmission } from '@lan-arcade/shared';
import {
  createApiClient,
  launchUrlForGame,
  loadApiState,
  normalizeApiUrl,
  saveApiState,
  type ApiClient
} from './lib/api';
import { TrailguardGame } from './games/trailguard/TrailguardGame';
import { NumberSplashGame } from './games/number-splash/NumberSplashGame';
import { CampColonyGame } from './games/camp-colony/CampColonyGame';

type ConnectionStatus = 'idle' | 'connecting' | 'connected' | 'error';

export function App() {
  const initial = useMemo(() => loadApiState(), []);
  const [apiUrl, setApiUrl] = useState(initial.apiUrl);
  const [sessionToken, setSessionToken] = useState(initial.sessionToken);
  const [player, setPlayer] = useState<Player | null>(initial.player);
  const [client, setClient] = useState<ApiClient>(() => createApiClient(initial.apiUrl));
  const [status, setStatus] = useState<ConnectionStatus>('idle');
  const [message, setMessage] = useState('Connect to a LAN Arcade server to sync scores and profiles.');
  const [catalog, setCatalog] = useState<ArcadeCatalog | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [activeGame, setActiveGame] = useState<ArcadeGame | null>(null);
  const [challenge, setChallenge] = useState<Challenge | null>(null);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [newPlayerName, setNewPlayerName] = useState('');
  const [newPlayerPin, setNewPlayerPin] = useState('');
  const [selectedPin, setSelectedPin] = useState('');
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    connect(initial.apiUrl).catch(() => undefined);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const visibleGames = useMemo(() => {
    const games = catalog?.games || [];
    if (filter === 'all') return games;
    if (filter === 'app') return games.filter((game) => game.source === 'app-web');
    if (filter === 'server') return games.filter((game) => game.source === 'lan-web' || game.source === 'lan-service');
    if (filter === 'scores') return games.filter((game) => game.scoreEnabled);
    return games.filter((game) => game.categories.includes(filter));
  }, [catalog, filter]);

  async function connect(url = apiUrl) {
    const normalized = normalizeApiUrl(url);
    const nextClient = createApiClient(normalized);
    setStatus('connecting');
    setMessage(`Connecting to ${normalized}`);
    try {
      const [info, nextCatalog, nextPlayers] = await Promise.all([
        nextClient.serverInfo(),
        nextClient.catalog(),
        nextClient.players()
      ]);
      setApiUrl(normalized);
      setClient(nextClient);
      setCatalog(nextCatalog);
      setPlayers(nextPlayers);
      setStatus('connected');
      setMessage(`Connected to ${info.name}. ${nextCatalog.games.length} games available.`);
      saveApiState({ apiUrl: normalized });
    } catch (error) {
      setStatus('error');
      setMessage(error instanceof Error ? error.message : 'Could not connect to server.');
    }
  }

  async function createPlayer() {
    if (!newPlayerName.trim()) return;
    const created = await client.createPlayer({ displayName: newPlayerName.trim(), pin: newPlayerPin.trim() || undefined });
    const session = await client.createSession({ playerId: created.id, pin: newPlayerPin.trim() || undefined });
    setPlayer(session.player);
    setSessionToken(session.token);
    setPlayers(await client.players());
    setNewPlayerName('');
    setNewPlayerPin('');
    saveApiState({ player: session.player, sessionToken: session.token });
    setMessage(`Player selected: ${session.player.displayName}`);
  }

  async function selectPlayer(nextPlayer: Player) {
    const session = await client.createSession({ playerId: nextPlayer.id, pin: selectedPin.trim() || undefined });
    setPlayer(session.player);
    setSessionToken(session.token);
    setSelectedPin('');
    saveApiState({ player: session.player, sessionToken: session.token });
    setMessage(`Player selected: ${session.player.displayName}`);
  }

  async function openGame(game: ArcadeGame) {
    setActiveGame(game);
    const nextChallenge = game.scoreEnabled ? await client.currentChallenge(game.id) : null;
    setChallenge(nextChallenge);
    setLeaderboard(game.scoreEnabled ? await client.leaderboard(game.id, nextChallenge?.seed) : []);
  }

  async function submitScore(score: ScoreSubmission) {
    if (!sessionToken) throw new Error('Select a player first.');
    await client.submitScore(score, sessionToken);
    const entries = await client.leaderboard(score.gameId, score.seed);
    setLeaderboard(entries);
    setMessage(`Score submitted for ${score.gameId}.`);
  }

  function clearPlayer() {
    setPlayer(null);
    setSessionToken('');
    saveApiState({ player: null, sessionToken: '' });
  }

  return (
    <main className="shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Off-grid game hub</p>
          <h1>LAN Arcade Companion</h1>
          <p>Launch local browser games, play app-only games, and sync profiles and scores to your camping server.</p>
        </div>
        <div className={`status-pill status-${status}`}>{status}</div>
      </header>

      <section className="panel server-panel" aria-label="Server connection">
        <label>
          Server API
          <input value={apiUrl} onChange={(event) => setApiUrl(event.target.value)} placeholder="http://server/arcade-api/" />
        </label>
        <button type="button" onClick={() => connect()}>Connect</button>
        <p>{message}</p>
      </section>

      <section className="columns">
        <section className="panel">
          <div className="section-head">
            <h2>Player</h2>
            {player && <button type="button" className="ghost" onClick={clearPlayer}>Switch</button>}
          </div>
          {player ? (
            <div className="selected-player">
              <span>{player.displayName}</span>
              <small>{player.pinProtected ? 'PIN protected' : 'Open profile'}</small>
            </div>
          ) : (
            <>
              <div className="form-grid">
                <input value={newPlayerName} onChange={(event) => setNewPlayerName(event.target.value)} placeholder="New player name" />
                <input value={newPlayerPin} onChange={(event) => setNewPlayerPin(event.target.value)} placeholder="Optional PIN" type="password" />
                <button type="button" onClick={createPlayer} disabled={status !== 'connected'}>Create</button>
              </div>
              <div className="player-list">
                <input value={selectedPin} onChange={(event) => setSelectedPin(event.target.value)} placeholder="PIN for selected profile, if needed" type="password" />
                {players.map((existing) => (
                  <button type="button" key={existing.id} onClick={() => selectPlayer(existing)}>
                    {existing.displayName}
                    {existing.pinProtected && <small>PIN</small>}
                  </button>
                ))}
              </div>
            </>
          )}
        </section>

        <section className="panel">
          <div className="section-head">
            <h2>Catalog</h2>
            <select value={filter} onChange={(event) => setFilter(event.target.value)} aria-label="Catalog filter">
              <option value="all">All</option>
              <option value="app">App-only</option>
              <option value="server">Server & services</option>
              <option value="scores">Score-enabled</option>
              {(catalog?.categories || []).map((category) => (
                <option value={category.id} key={category.id}>{category.label}</option>
              ))}
            </select>
          </div>
          <div className="game-grid">
            {visibleGames.map((game) => (
              <article className="game-card" key={game.id}>
                <div className="game-icon">{game.icon}</div>
                <h3>{game.title}</h3>
                <p className="meta">{game.meta}</p>
                <p>{game.description}</p>
                <div className="tag-row">
                  <span>{game.source === 'app-web' ? 'App-only' : game.source === 'lan-service' ? 'Pi service' : 'LAN web'}</span>
                  {game.scoreEnabled && <span>Scores</span>}
                </div>
                <button type="button" aria-label={`Open ${game.title}`} onClick={() => openGame(game)}>Open</button>
              </article>
            ))}
          </div>
        </section>
      </section>

      {activeGame && (
        <section className="panel play-panel">
          <div className="section-head">
            <div>
              <h2>{activeGame.title}</h2>
              {challenge && <p>Challenge seed: {challenge.seed}</p>}
            </div>
            <button type="button" className="ghost" onClick={() => setActiveGame(null)}>Close</button>
          </div>

          {activeGame.source === 'lan-web' && activeGame.launchPath && (
            <a className="launch-link" href={launchUrlForGame(apiUrl, activeGame.launchPath)} target="_blank" rel="noreferrer">
              Launch {activeGame.title}
            </a>
          )}

          {activeGame.source === 'lan-service' && (
            <div className="service-panel" data-testid="lan-service-panel">
              <h3>{activeGame.title}</h3>
              <p>{activeGame.connectionHint || 'Use the matching game client and join the LAN server.'}</p>
              {activeGame.serverPort && <strong>Default LAN port: {activeGame.serverPort}</strong>}
            </div>
          )}

          {activeGame.id === 'camp-colony' && (
            <CampColonyGame challenge={challenge} player={player} onSubmitScore={submitScore} />
          )}

          {activeGame.id === 'trailguard-td' && (
            <TrailguardGame challenge={challenge} player={player} sessionToken={sessionToken} onSubmitScore={submitScore} />
          )}

          {activeGame.id === 'number-splash' && (
            <NumberSplashGame challenge={challenge} player={player} onSubmitScore={submitScore} />
          )}

          {activeGame.scoreEnabled && (
            <div className="leaderboard">
              <h3>Leaderboard</h3>
              {leaderboard.length === 0 ? <p>No scores yet for this seed.</p> : leaderboard.map((entry, index) => (
                <div className="leaderboard-row" key={entry.id}>
                  <span>{index + 1}. {entry.playerName}</span>
                  <strong>{entry.score.toLocaleString()}</strong>
                </div>
              ))}
            </div>
          )}
        </section>
      )}
    </main>
  );
}
