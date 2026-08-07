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

import WrappedPlayer from './WrappedPlayer';
import audio from '@ohos.multimedia.audio';
import AudioContextOhos from '../AudioContextOhos';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { HashMap } from '@kit.ArkTS';
import { Log } from '@ohos/flutter_ohos';


const TAG = 'FocusManager';

const API_6_0 = 20;

/**
 * 焦点管理是应用级别，各个player的焦点策略，都会被应用到全局
 */
export default class FocusManager {
  private static instance: FocusManager = new FocusManager();

  public static getInstance() {
    return FocusManager.instance;
  }

  //订阅焦点的播放器，第二个值，代表是否因为焦点事件中断，为true时，重新获取焦点后，会继续播放
  private subscribedPlayerSet: HashMap<WrappedPlayer, boolean> = new HashMap();
  private audioSessionManager?: audio.AudioSessionManager;
  private context?: AudioContextOhos;
  private audioSessionDeactivatedCallback?: (audioSessionDeactivatedEvent: audio.AudioSessionDeactivatedEvent) => void;
  private audioSessionStateChangedCallback?: (audioSessionStateChangedEvent: audio.AudioSessionStateChangedEvent) => void;

  constructor() {
    try {
      let audioManager = audio.getAudioManager();
      this.audioSessionManager = audioManager.getSessionManager();
      this.subscribeFocusCallback();
    } catch (e) {
      // 单例在静态初始化时构造，不能抛异常；记录后由 init() 惰性重试
      Log.e(TAG, `FocusManager init failed: ${(e as Error).message}`);
    }
  }

  /**
   * 惰性获取 AudioSessionManager：构造失败时在首次使用/init() 时重试。
   */
  private getSessionManager(): audio.AudioSessionManager {
    if (this.audioSessionManager == null) {
      let audioManager = audio.getAudioManager();
      this.audioSessionManager = audioManager.getSessionManager();
    }
    return this.audioSessionManager!
  }

  subscribePlayer(player: WrappedPlayer) {
    if (!this.subscribedPlayerSet.hasKey(player)) {
      this.subscribedPlayerSet.set(player, false);
    }
  }

  /**
   * 重新绑定引擎时调用，幂等订阅音频焦点事件。
   * dispose() 取消订阅后会清除回调引用，再次调用 init() 即可重新订阅。
   * 仅当所有必要回调都已注册时才跳过，避免部分回调丢失后无法恢复。
   */
  init(): void {
    if (this.audioSessionDeactivatedCallback != null &&
      (deviceInfo.sdkApiVersion < API_6_0 || this.audioSessionStateChangedCallback != null)) {
      return;
    }
    this.subscribeFocusCallback();
  }

  unsubscribePlayer(player: WrappedPlayer) {
    if (this.subscribedPlayerSet.hasKey(player)) {
      this.subscribedPlayerSet.remove(player);
    }
  }

  //停用音频焦点
  handleStop(player: WrappedPlayer) {
    if (this.hasOtherPlayerPlaying(player)) {
      return;
    }
    if (this.hasAudioFocus()) {
      this.deactivateAudioSession();
    }
  }

  /**
   * 每次的策略，都根据最新请求焦点的播放器决定。 如果已有音频焦点，不更新策略。
   * @param player
   */
  maybeRequestAudioFocus(player: WrappedPlayer) {
    this.subscribePlayer(player);
    this.context = player.context;
    //如果已有焦点，直接播放
    if (this.hasAudioFocus()) {
      player.actuallyPlay();
      return;
    }
    let strategy: audio.AudioSessionStrategy = {
      concurrencyMode: this.getFocusStrategy()
    };
    if (deviceInfo.sdkApiVersion >= API_6_0) {
      try {
        this.getSessionManager().setAudioSessionScene(audio.AudioSessionScene.AUDIO_SESSION_SCENE_MEDIA);
      } catch (e) {
        Log.e(TAG, `setAudioSessionScene failed: ${(e as Error).message}`);
        player.handleError('AudioSessionSceneError', (e as Error).message, null);
        return;
      }
    }
    //请求焦点之后，开始播放
    this.getSessionManager().activateAudioSession(strategy).then(() => {
      Log.d(TAG, 'Succeeded in doing activateAudioSession.');
      player.actuallyPlay();
    }).catch((err: BusinessError) => {
      Log.e(TAG, `Failed to activateAudioSession. Code: ${err.code}, message: ${err.message}`);
      player.handleError('AudioFocusError', err.message, err);
    });
  }

  dispose(): void {
    try {
      if (this.hasAudioFocus()) {
        this.deactivateAudioSession();
      }
    } catch (e) {
      Log.e(TAG, `deactivateAudioSession in dispose failed: ${(e as Error).message}`);
    }
    if (this.audioSessionDeactivatedCallback) {
      try {
        this.getSessionManager().off('audioSessionDeactivated', this.audioSessionDeactivatedCallback);
      } catch (e) {
        Log.e(TAG, `off audioSessionDeactivated in dispose failed: ${(e as Error).message}`);
      }
      this.audioSessionDeactivatedCallback = undefined;
    }
    if (deviceInfo.sdkApiVersion >= API_6_0 && this.audioSessionStateChangedCallback) {
      try {
        this.getSessionManager().off('audioSessionStateChanged', this.audioSessionStateChangedCallback);
      } catch (e) {
        Log.e(TAG, `off audioSessionStateChanged in dispose failed: ${(e as Error).message}`);
      }
      this.audioSessionStateChangedCallback = undefined;
    }
    // 清理订阅播放器集合，避免已 dispose 的播放器引用残留与集合无限累积
    this.subscribedPlayerSet.clear()
    this.context = undefined
  }


  private onGranted() {
    try {
      // 使用集合快照遍历，避免异步操作期间集合被修改导致迭代不一致
      const players: WrappedPlayer[] = []
      this.subscribedPlayerSet.forEach((isSuspend, player) => {
        if (player != null && isSuspend) {
          players.push(player);
        }
      })
      for (const player of players) {
        player.actuallyPlay();
      }
    } catch (e) {
      Log.e(TAG, `onGranted error: ${(e as Error).message}`);
    }
  }

  private onLoss(isTransient: boolean) {
    try {
      // 使用集合快照遍历，避免异步操作期间集合被修改导致迭代不一致
      const playing: WrappedPlayer[] = []
      this.subscribedPlayerSet.forEach((_isSuspend, player) => {
        //失去焦点后，暂停所有播放器
        if (player != null && player.isPlaying()) {
          playing.push(player);
        }
      })
      for (const player of playing) {
        //如果是暂时中断，标记，代表下次可能重新获取焦点
        if (isTransient) {
          this.subscribedPlayerSet.set(player, true);
        }
        player.pause();
      }
    } catch (e) {
      Log.e(TAG, `onLoss error: ${(e as Error).message}`);
    }
  }


  private hasOtherPlayerPlaying(currentPlayer: WrappedPlayer): boolean {
    let hasOtherPlaying: boolean = false;
    this.subscribedPlayerSet.forEach((isSuspend, player) => {
      if (currentPlayer != player && player?.isPlaying()) {
        hasOtherPlaying = true;
      }
    })
    return hasOtherPlaying;
  }


  private deactivateAudioSession() {
    this.getSessionManager().deactivateAudioSession().then(() => {
      Log.d(TAG, 'Succeeded in doing deactivateAudioSession.');
    }).catch((err: BusinessError) => {
      Log.e(TAG, `Failed to deactivateAudioSession. Code: ${err.code}, message: ${err.message}`);
    });
  }


  private subscribeFocusCallback() {
    const sessionManager = this.getSessionManager()
    this.audioSessionDeactivatedCallback = (audioSessionDeactivatedEvent: audio.AudioSessionDeactivatedEvent) => {
      try {
        Log.d(TAG, `audioSessionDeactivatedCallback: ${audioSessionDeactivatedEvent.reason.toString()} `);
        this.onLoss(false);
      } catch (e) {
        Log.e(TAG, `audioSessionDeactivatedCallback error: ${e.message}`);
      }
    }
    sessionManager.on('audioSessionDeactivated', this.audioSessionDeactivatedCallback);
    if (deviceInfo.sdkApiVersion >= API_6_0) {
      this.audioSessionStateChangedCallback = (audioSessionStateChangedEvent: audio.AudioSessionStateChangedEvent) => {
        try {
          Log.d(TAG, `hint of audioSessionStateChanged: ${audioSessionStateChangedEvent.stateChangeHint} `);
          switch (audioSessionStateChangedEvent.stateChangeHint) {
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_PAUSE:
              // 此分支表示系统已将音频流暂停，应用需切换至音频暂停状态。
              // 临时失去焦点：其他音频流释放音频焦点后，本音频流会收到resume事件，可继续播放。
              this.onLoss(true);
              break;
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_RESUME:
              // 此分支表示系统解除AudioSession焦点的暂停操作。
              this.onGranted();
              break;
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_STOP:
              // 此分支表示系统已将音频流停止（永久失去焦点），为保持状态一致，应用需切换至音频暂停状态。
              // 永久失去焦点：后续不会再收到音频焦点事件，恢复播放需用户主动触发。
              this.onLoss(false);
              break;
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_TIME_OUT_STOP:
              // 此分支表示由于长时间无音频流播放，系统已将AudioSession停止（永久失去焦点），应用需切换至音频暂停状态。
              // 永久失去焦点：后续不会再收到音频焦点事件，恢复播放需用户主动触发。
              this.onLoss(false);
              break;
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_DUCK:
              // 此分支表示系统已将音频音量降低（默认降到正常音量的20%）。
              break;
            case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_UNDUCK:
              // 此分支表示系统已将音频音量恢复正常。
              break;
            default:
              break;
          }
        } catch (e) {
          Log.e(TAG, `audioSessionStateChangedCallback error: ${e.message}`);
        }
      };
      sessionManager.on('audioSessionStateChanged', this.audioSessionStateChangedCallback);
    }
  }


  private hasAudioFocus(): boolean {
    try {
      return this.getSessionManager().isAudioSessionActivated();
    } catch (e) {
      Log.e(TAG, `isAudioSessionActivated failed: ${(e as Error).message}`);
      return false;
    }
  }

  private getFocusStrategy(): audio.AudioConcurrencyMode {
    switch (this.context?.audioFocus) {
      case 1: //对应dart侧AudioContextConfigFocus.duckOthers
        return audio.AudioConcurrencyMode.CONCURRENCY_DUCK_OTHERS;
      case 2: //对应dart侧AudioContextConfigFocus.mixWithOthers
        return audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS;
      case 0: //对应dart侧AudioContextConfigFocus.gain
      default:
        return audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT;
    }
  }
}