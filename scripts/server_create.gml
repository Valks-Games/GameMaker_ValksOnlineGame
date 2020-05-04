#define server_create
///server_create(port)

var 
port = argument0,
server = 0;

server = network_create_server_raw(network_socket_tcp, port, 20);
clientmap = ds_map_create();
client_id_counter = 0;

send_buffer = buffer_create(256, buffer_fixed, 1);

if (server < 0) show_error("Could not Create Server!", true);

return server;

#define server_handle_connect
///server_handle_connect(socketid)

var
socket_id = argument0;

var
l = instance_create(0,0, oServerClient);

l.socket_id = socket_id;
l.client_id = client_id_counter++;

if (client_id_counter >= 65000){
  cliend_id_counter = 0;
}

clientmap[? string(socket_id)] = l;

buffer_seek(send_buffer, buffer_seek_start, 0);
buffer_write(send_buffer, buffer_u8, MESSAGE_GETID);
buffer_write(send_buffer, buffer_u16, l.client_id);
network_send_raw(socket_id,send_buffer,buffer_tell(send_buffer));

#define server_handle_message
///server_handle_message(socket_id,buffer)

var
socket_id = argument0,
buffer = argument1,
clientobject = clientmap[? string(socket_id)],
client_id_current = clientobject.client_id;

while(true){
  var
  message_id = buffer_read(buffer, buffer_u8);
  
  switch(message_id){
    case MESSAGE_MOVE:
      var
      xx = buffer_read(buffer, buffer_u16);
      yy = buffer_read(buffer, buffer_u16);
      dir = buffer_read(buffer, buffer_u16);
      
      clientobject.x = xx;
      clientobject.y = yy;
      
      buffer_seek(send_buffer, buffer_seek_start, 0);
      buffer_write(send_buffer, buffer_u8, MESSAGE_MOVE);
      buffer_write(send_buffer, buffer_u16, client_id_current);
      buffer_write(send_buffer, buffer_u16, xx);
      buffer_write(send_buffer, buffer_u16, yy);
      buffer_write(send_buffer, buffer_u16, dir);
      
      with(oServerClient){
        if (client_id != client_id_current){
          network_send_raw(self.socket_id, other.send_buffer, buffer_tell(other.send_buffer));
        }
      }
    break;
    case MESSAGE_JOIN:
      username = buffer_read(buffer, buffer_string);
      clientobject.name = username;
      
      buffer_seek(send_buffer, buffer_seek_start, 0);
      buffer_write(send_buffer, buffer_u8, MESSAGE_JOIN);
      buffer_write(send_buffer, buffer_u16, client_id_current);
      buffer_write(send_buffer, buffer_string, username);
      
      //sending the newly joining name to all other clients
      with(oServerClient){
        if (client_id != client_id_current){
          network_send_raw(self.socket_id, other.send_buffer, buffer_tell(other.send_buffer));
        }
      }
        
      //send the newly joined client the name of all other clients
      with(oServerClient){
        if (client_id != client_id_current){
          buffer_seek(other.send_buffer, buffer_seek_start, 0);
          buffer_write(other.send_buffer, buffer_u8, MESSAGE_JOIN);
          buffer_write(other.send_buffer, buffer_u16, client_id);
          buffer_write(other.send_buffer, buffer_string, name);
          network_send_raw(socket_id, other.send_buffer, buffer_tell(other.send_buffer));
        }
      }
    break;
    case MESSAGE_SHOOT:
      var
      shootdirection = buffer_read(buffer, buffer_u16);
      
      server_handle_shoot(shootdirection, clientobject);
      
    break;
  }
  
  if (buffer_tell(buffer) == buffer_get_size(buffer)){
    break;
  }
  
}

#define server_handle_disconnect
///server_handle_disconnect(socketid)

var
socket_id = argument0;

buffer_seek(send_buffer, buffer_seek_start, 0);
buffer_write(send_buffer, buffer_u8, MESSAGE_LEAVE);
buffer_write(send_buffer, buffer_u16, clientmap[? string(socket_id)].client_id);

with(clientmap[? (string(socket_id))]) {
  instance_destroy();
}

ds_map_delete(clientmap, string(socket_id));

with(oServerClient){
  network_send_raw(self.socket_id, other.send_buffer, buffer_tell(other.send_buffer));
}

#define server_handle_shoot
///server_handle_shoot(shootdirection, clientobject)

var
shootdirection = argument0,
tempobject = argument1,
hit = false,
obj = noone;

var
prx = tempobject.x,
pry = tempobject.y,
prog = 0,
tox = prx,
toy = pry;

with(tempobject){
  while(prog < SHOOT_RANGE){
    tox = prx + lengthdir_x(10, shootdirection);
    toy = pry + lengthdir_y(10, shootdirection);
    obj = collision_line(prx, pry, tox, toy, all, false, true);
    if (instance_exists(obj)){
      //hit!
      hit = true;
      prog += 10;
      break;
    }
    prx = tox;
    pry = toy;
    prog += 10;
  }
  
  create_shootline(x,y,tox,toy);
}

if (hit){
  obj.hp -= 1;
  if (obj.hp <= 0){
    obj.hp = 20;
  }

  buffer_seek(send_buffer, buffer_seek_start, 0);
  buffer_write(send_buffer, buffer_u8, MESSAGE_HIT);
  buffer_write(send_buffer, buffer_u16, tempobject.client_id);
  buffer_write(send_buffer, buffer_u16, obj.client_id);
  buffer_write(send_buffer, buffer_u16, shootdirection);
  buffer_write(send_buffer, buffer_u16, prog);
  buffer_write(send_buffer, buffer_u8, obj.hp);
  with(oServerClient){
    network_send_raw(self.socket_id, other.send_buffer, buffer_tell(other.send_buffer));
  }
} else {
  buffer_seek(send_buffer, buffer_seek_start, 0);
  buffer_write(send_buffer, buffer_u8, MESSAGE_MISS);
  buffer_write(send_buffer, buffer_u16, tempobject.client_id);
  buffer_write(send_buffer, buffer_u16, shootdirection);
  buffer_write(send_buffer, buffer_u16, prog);
  with(oServerClient){
    network_send_raw(self.socket_id, other.send_buffer, buffer_tell(other.send_buffer));
  }
}