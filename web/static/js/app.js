import $ from 'jquery';
import Player from './player';
import Table from './table';

class App {
  static init() {
    let playerName = localStorage.getItem("playerName") || "unknown_player"
    let player = new Player(playerName)
    let table = new Table("table_one")

    table.join(player)
    window.table = table;
  }
}

$(() => App.init());

export default App;
