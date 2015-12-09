export default class Table {
  constructor(name) {
    this.channelName = `tables:${name}`;
  }

  join(player) {
    this.channel = player.connection.channel(this.channelName, {});

    this.channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })

    this.channel.on("update", this.onUpdateState.bind(this))
  }

  onUpdateState(state) {
    console.log(state)
    this.state = state
  }

  sit(position) { this.executeCommand("sit", position) }
  leave() { this.executeCommand("leave") }
  buyIn(amount) { this.executeCommand("buy_in", amount) }
  cashOut() { this.executeCommand("cash_out") }
  deal() { this.executeCommand("deal") }

  executeCommand(command, ...args) {
    this.channel
      .push(command, args)
      .receive("error", resp => { console.log(`Error executing command '${command}':`, resp)})
  }
}
