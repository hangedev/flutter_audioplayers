/**
 * Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
import audio from '@ohos.multimedia.audio';
import media from '@ohos.multimedia.media';
import AudioContextOhos from '../AudioContextOhos';
import AudioplayersPlugin from '../AudioplayersPlugin';
import Source from '../source/Source';
import UrlSource from '../source/UrlSource';
import Player from './Player';
import WrappedPlayer from './WrappedPlayer';
import { HashMap } from '@kit.ArkTS';

const MAX_STREAMS = 32;
const MAX_SOUND_POOL_WRAPPERS = 8;

export default class SoundPoolPlayer implements Player {
  wrappedPlayer: WrappedPlayer;
  private soundPoolManager: SoundPoolManager;
  soundId: number | null = null;
  private streamId: number | null = null;
  private audioContext: AudioContextOhos;
  private soundPoolWrapper: SoundPoolWrapper | null = null;
  private soundPool: media.SoundPool | null = null;
  // 缓存当前源引用：release()/源切换时 WrappedPlayer.source 可能已被替换，
  // 若依赖 wrappedPlayer.getSource() 会拿到新源导致旧音效无法卸载（泄漏）
  private cachedUrlSource: UrlSource | null = null;

  constructor(wrappedPlayer: WrappedPlayer, soundPoolManager: SoundPoolManager) {
    this.wrappedPlayer = wrappedPlayer;
    this.soundPoolManager = soundPoolManager;
    this.audioContext = wrappedPlayer.context;
  }

  async init() {
    await this.soundPoolManager.createSoundPoolWrapper(MAX_STREAMS, this.audioContext);
    this.soundPoolWrapper = this.soundPoolManager.getSoundPoolWrapper(this.audioContext);
    if (this.soundPoolWrapper == null || this.soundPoolWrapper.soundPool == null) {
      this.wrappedPlayer.handleError('SoundPoolInitError', 'Failed to get SoundPool wrapper', null);
      return;
    }
    this.soundPool = this.soundPoolWrapper.soundPool;
  }

  async setAudioContext(audioContext: AudioContextOhos) {
    if (!this.audioContext.equals(audioContext)) {
      this.audioContext = audioContext;
      await this.release();
      await this.init()
    }
  }

  getDuration(): number | null {
    return null;
  }

  getCurrentPosition(): number | null {
    return null;
  }

  isActuallyPlaying(): boolean {
    return false;
  }

  isLiveStream(): boolean {
    return false;
  }

  async start() {
    let soundId = this.soundId
    if (soundId != null && this.soundPool != null) {
      let playParameters: media.PlayParameters = {
        loop: this.wrappedPlayer.getLooping() ? -1 : 0,
        rate: this.convertRate(this.wrappedPlayer.getRate()), // 正常倍速
        leftVolume: this.wrappedPlayer.getVolume(), // range = 0.0-1.0
        rightVolume: this.wrappedPlayer.getVolume(), // range = 0.0-1.0
        priority: 0, // 最低优先级
      }
      try {
        this.streamId = await this.soundPool.play(soundId, playParameters)
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolPlayError', (e as Error).message, null)
      }
    }
  }

  pause() {
    if (this.streamId != null && this.soundPool != null) {
      try {
        // OHOS SoundPool 无独立 pause；stop 暂停当前流，下次 start 会重新 play
        this.soundPool.stop(this.streamId)
        this.streamId = null;
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolPauseError', (e as Error).message, null)
      }
    }
  }

  stop() {
    if (this.streamId != null && this.soundPool != null) {
      try {
        this.soundPool.stop(this.streamId)
        this.streamId = null;
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolStopError', (e as Error).message, null)
      }
    }
  }

  seekTo(position: number) {
    // OHOS SoundPool 不支持 seek；记录日志避免静默空操作
    this.wrappedPlayer.handleLog(`SoundPool seekTo(${position}) is unsupported on OHOS LOW_LATENCY mode`)
  }

  async release() {
    await this.stop()
    if (this.soundId == null) {
      return
    }
    if (this.getUrlSource() == null) {
      return;
    }
    if (this.soundPoolWrapper == null || !this.soundPoolWrapper.urlToPlayers.hasKey(this.getUrlSource())) {
      return;
    }
    let playersForSoundId = this.soundPoolWrapper.urlToPlayers.get(this.getUrlSource());
    if (playersForSoundId.length == 1 && playersForSoundId[0] == this) {
      this.soundPoolWrapper.urlToPlayers.remove(this.getUrlSource())
      try {
        if (this.soundPool != null) {
          await this.soundPool.unload(this.soundId)
        }
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolUnloadError', (e as Error).message, null)
      }
      this.soundPoolWrapper.soundIdToPlayer.remove(this.soundId)
      this.wrappedPlayer.handleLog('unloaded soundId $soundId')
      // 关闭 SoundPool 占用的 fd / 清理临时文件
      this.getUrlSource()?.closeSoundPoolResources()
    } else {
      // This is not the last player using the soundId, just remove it from the list.
      let index = playersForSoundId.indexOf(this);
      if (index > -1) {
        playersForSoundId.splice(index, 1)
      }
    }
    this.soundId = null
    this.cachedUrlSource = null
  }

  async setVolume(leftVolume: number, rightVolume: number) {
    if (this.streamId != null && this.soundPool != null) {
      try {
        await this.soundPool.setVolume(this.streamId, leftVolume, rightVolume)
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolVolumeError', (e as Error).message, null)
      }
    }
  }

  async setRate(rate: number) {
    if (this.streamId != null && this.soundPool != null) {
      try {
        await this.soundPool.setRate(this.streamId, this.convertRate(rate))
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolRateError', (e as Error).message, null)
      }
    }
  }

  async setLooping(looping: boolean) {
    if (this.streamId != null && this.soundPool != null) {
      try {
        await this.soundPool.setLoop(this.streamId, looping ? -1 : 0);
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolLoopError', (e as Error).message, null)
      }
    }
  }

  updateContext(context: AudioContextOhos) {
    this.audioContext = context
  }

  async setSource(source: Source): Promise<void> {
    await source.setForSoundPool(this)
  }

  async prepare(): Promise<void> {
    // sound pool automatically prepares when source URL is set
  }

  async reset(): Promise<void> {
    // 低延迟模式下 reset 等价于停止当前流并释放流句柄；下次 start 会重新 play
    if (this.streamId != null && this.soundPool != null) {
      try {
        this.soundPool.stop(this.streamId)
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolResetError', (e as Error).message, null)
      }
      this.streamId = null;
    }
  }

  private unsupportedOperation(message: string) {
    throw new Error(`LOW_LATENCY mode does not support: ${message}`)
  }

  private convertRate(rate: number): audio.AudioRendererRate {
    let ohrate = audio.AudioRendererRate.RENDER_RATE_NORMAL;
    if (this.wrappedPlayer.getRate() < 1) {
      ohrate = audio.AudioRendererRate.RENDER_RATE_HALF;
    } else if (this.wrappedPlayer.getRate() > 1) {
      ohrate = audio.AudioRendererRate.RENDER_RATE_DOUBLE;
    }
    return ohrate;
  }

  async setUrlSource(urlSource: UrlSource) {
    if (this.soundId != null) {
      await this.release()
    }
    // release() 完成后再缓存新源，保证卸载旧音效时 cachedUrlSource 仍指向旧源
    this.cachedUrlSource = urlSource
    if (this.soundPoolWrapper == null || this.soundPool == null) {
      this.wrappedPlayer.handleError('SoundPoolNotReady', 'SoundPool is not initialized', null)
      return
    }
    if (!this.soundPoolWrapper.urlToPlayers.hasKey(urlSource)) {
      this.soundPoolWrapper.urlToPlayers.set(urlSource, Array<SoundPoolPlayer>())
    }
    let urlPlayers = this.soundPoolWrapper.urlToPlayers.get(urlSource);
    let originalPlayer = urlPlayers.length > 0 ? urlPlayers[0] : null;
    if (originalPlayer != null) {
      // Sound has already been loaded - reuse the soundId.
      let prepared = originalPlayer.wrappedPlayer.getPrepared();
      this.wrappedPlayer.setPrepared(prepared);
      this.soundId = originalPlayer.soundId
      this.wrappedPlayer.handleLog(`Reusing soundId ${this.soundId} for ${urlSource.url} is prepared=${prepared}`)
    } else {
      // First one for this URL - load it.
      let start = new Date().getTime();
      this.wrappedPlayer.setPrepared(false);
      this.wrappedPlayer.handleLog(`Fetching actual URL for ${urlSource.url}}`)
      try {
        let context = this.wrappedPlayer.getApplicationContext();
        if (context == null) {
          // WrappedPlayer 已 dispose（ref 置空），无法获取应用上下文，直接报错返回
          this.wrappedPlayer.handleError('SoundPoolLoadError', 'WrappedPlayer is disposed', null)
          return
        }
        let actualUrl = await urlSource.getAudioPathForSoundPool(context);
        this.wrappedPlayer.handleLog(`Now loading ${actualUrl}`)
        let intSoundId = await this.soundPool.load(actualUrl)
        this.soundPoolWrapper.soundIdToPlayer.set(intSoundId, this)
        this.soundId = intSoundId
        this.wrappedPlayer.handleLog(`time to call load() for ${urlSource.url}: ${new Date().getTime() - start} player=${this}}`,)
      } catch (e) {
        this.wrappedPlayer.handleError('SoundPoolLoadError', (e as Error).message, null)
        return
      }
    }
    urlPlayers.push(this);
  }

  getUrlSource(): UrlSource | null {
    return this.cachedUrlSource
  }
}

export class SoundPoolManager {
  private ref: AudioplayersPlugin;
  private legacySoundPoolWrapper: SoundPoolWrapper | null = null
  private soundPoolWrappers = new HashMap<string, SoundPoolWrapper>()

  constructor(plugin: AudioplayersPlugin) {
    this.ref = plugin;
  }

  async createSoundPoolWrapper(maxStreams: number, audioContext: AudioContextOhos) {
    let attrs = audioContext.buildAttributes();
    let key = attrs.usage + '' + attrs.rendererFlags;
    if (!this.soundPoolWrappers.hasKey(key)) {
      // 限制缓存数量，避免不同 AudioContext 组合导致无限增长
      if (this.soundPoolWrappers.length >= MAX_SOUND_POOL_WRAPPERS) {
        let oldestKey: string | null = null
        this.soundPoolWrappers.forEach((_v: SoundPoolWrapper, k: string) => {
          if (oldestKey == null) {
            oldestKey = k
          }
        })
        if (oldestKey != null) {
          let old = this.soundPoolWrappers.get(oldestKey)
          old.dispose()
          this.soundPoolWrappers.remove(oldestKey)
        }
      }
      let soundPool = await media.createSoundPool(maxStreams, attrs);
      this.ref.handleGlobalLog('Create SoundPool with ' + key);
      let soundPoolWrapper = new SoundPoolWrapper(soundPool);
      soundPoolWrapper.loadCompleteCallback = (soundId: number) => {
        this.ref.handleGlobalLog(`Loaded ${soundId}`)
        let loadingPlayer = soundPoolWrapper.soundIdToPlayer.get(soundId)
        if (loadingPlayer == null) {
          return
        }
        let urlSource = loadingPlayer.getUrlSource()
        if (urlSource) {
          soundPoolWrapper.soundIdToPlayer.remove(loadingPlayer.soundId);
          let urlPlayers = soundPoolWrapper.urlToPlayers.get(urlSource)
          for (let player of urlPlayers) {
            player.wrappedPlayer.handleLog(`Marking ${player.soundId} as loaded`);
            player.wrappedPlayer.setPrepared(true);
            if (player.wrappedPlayer.isPlaying()) {
              player.wrappedPlayer.handleLog(`Delayed start of ${player.soundId}`);
              player.start();
            }
          }
        }
      };
      soundPoolWrapper.soundPool.on('loadComplete', soundPoolWrapper.loadCompleteCallback);
      this.soundPoolWrappers.set(key, soundPoolWrapper);
    }
  }

  /**
   * Get the [SoundPoolWrapper] with the given [audioContext].
   */
  getSoundPoolWrapper(audioContext: AudioContextOhos): SoundPoolWrapper | null {
    let attrs = audioContext.buildAttributes();
    let key = attrs.usage + '' + attrs.rendererFlags;
    return this.soundPoolWrappers.hasKey(key) ? this.soundPoolWrappers.get(key) : null;
  }

  dispose() {
    this.soundPoolWrappers.forEach((value: SoundPoolWrapper, key: string) => value.dispose())
    this.soundPoolWrappers.clear()
  }
}

class SoundPoolWrapper {
  soundPool: media.SoundPool;
  soundIdToPlayer = new HashMap<number, SoundPoolPlayer>()
  urlToPlayers = new  HashMap<UrlSource, Array<SoundPoolPlayer>>()
  loadCompleteCallback: ((soundId: number) => void) | null = null

  constructor(soundPool: media.SoundPool) {
    this.soundPool = soundPool;
  }

  /** For the onLoadComplete listener, track which sound id is associated with which player. An entry only exists until
   * it has been loaded.
   */

  /** This is to keep track of the players which share the same sound id, referenced by url. When a player release()s, it
   * is removed from the associated player list. The last player to be removed actually unloads() the sound id and then
   * the url is removed from this map.
   */
  dispose() {
    // SDK 类型定义中 off('loadComplete') 仅支持单参重载（移除该类型全部监听）；
    // 每个 SoundPoolWrapper 独占一个 SoundPool 实例，整体移除是安全的
    if (this.loadCompleteCallback != null) {
      this.soundPool.off('loadComplete');
      this.loadCompleteCallback = null
    }
    this.soundPool.release();
    this.soundIdToPlayer.clear();
    this.urlToPlayers.clear();
  }
}