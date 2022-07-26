import json
import websockets
import asyncio

from datetime import datetime
start_time = datetime.now()

port = 1234

print("Started server on port : ", port)

async def transmit(websocket, path):
    print("Client Connected!")
    try:
        f = open('lib/data/data.json')
        data = json.load(f)
        
        await websocket.send(json.dumps(data)) 

    except websockets.connection.ConnectionClosed as e:
        print("Client Disconnected!")
start_server = websockets.serve(transmit, port=port)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
