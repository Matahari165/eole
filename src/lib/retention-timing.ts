export function getNewRetentionMinute(elapsedSeconds: number, lastMinute: number) {
  const completedMinute = Math.floor(elapsedSeconds / 60);
  return completedMinute > 0 && completedMinute > lastMinute ? completedMinute : null;
}
