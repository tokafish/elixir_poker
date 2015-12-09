import {Socket} from "deps/phoenix/web/static/js/phoenix"

export default class Player {
  constructor(id) {
    let socket = new Socket("/socket", {params: {playerId: id}});
    socket.connect();

    this.id = id;
    this.connection = socket;
  }
}
