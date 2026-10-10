const video = document.querySelector("video");
const status = document.getElementById("status");
function showPlaybackState() {
  if (video.readyState >= 2 && (!video.videoWidth || !video.videoHeight)) {
    status.textContent = "未能解码视频画面：当前浏览器可能不支持此视频编码（例如 HEVC/H.265），即使时间前进也可能只有声音。请使用支持该编码的本机播放器打开视频流。";
  } else if (video.readyState >= 2) {
    status.textContent = video.paused ? "视频已就绪，点击播放。" : "正在播放。";
  }
}
for (const event of ["loadeddata", "canplay", "playing", "pause"]) video.addEventListener(event, showPlaybackState);
video.addEventListener("error", () => {
  const messages = { 1: "播放已取消。", 2: "视频读取失败，请检查测试终端的错误。", 3: "视频解码失败，请使用支持此编码的本机播放器。", 4: "浏览器不支持此视频格式，请使用支持此编码的本机播放器。" };
  status.textContent = messages[video.error?.code] ?? "视频播放失败，请检查测试终端。";
});
showPlaybackState();
