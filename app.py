import asyncio
import dotenv
from asyncio import subprocess
from asyncio.exceptions import CancelledError
from asyncio.tasks import Task
from quart import Quart, render_template, websocket
from logging import debug, warning, info, error, critical
import logging
import os

dotenv.load_dotenv()

DEFAULT_FILE = os.environ.get("HUEPL_DEFAULT_FILE")


app = Quart(__name__)


async def file_reporter(websocket):
    while True:
        result = []
        for root, dirs, files in os.walk("code/"):
            root = root.replace("code/", "")
            for file in files:
                result.append(os.path.join(root, file))
        await websocket.send_json({
            'response': 'files',
            'data': result
        })
        await asyncio.sleep(3)


async def relay_stream(proc, stream, websocket, name):
    while proc.returncode == None:

        to_read = len(stream._buffer)
        if to_read > 0:

            bytes_read = await stream.read(to_read)
            text = bytes_read.decode('utf-8')

            if text != "":
                await websocket.send_json({
                    'response': name,
                    'data': text
                })
        await asyncio.sleep(0)


async def run_code(websocket, filename):
    if not os.path.isfile(os.path.join("code", filename)):
        await websocket.send_json({
            'response': 'error',
            'description': 'File does not exist'
        })
        return

    os.system(
        f'chmod +x {os.path.join("code", filename)}')
    info("Changed permissions!")
    try:
        proc = await asyncio.create_subprocess_shell(os.path.join("code", filename),
                                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        stdrelay = asyncio.create_task(relay_stream(proc,
                                                    proc.stdout, websocket, 'stdout'))
        errrelay = asyncio.create_task(relay_stream(proc,
                                                    proc.stderr, websocket, 'stderr'))

        code = await proc.wait()
        await websocket.send_json({
            'response': "finished",
            'data': code
        })
    except CancelledError:
        info("Cleaning code runner")
        if stdrelay != None:
            stdrelay.cancel()
        if errrelay != None:
            errrelay.cancel()
        proc.terminate()


@app.websocket('/api/v2/ws')
async def ws():

    info("Websocket connected")
    runner_coro = None
    reporter_coro = asyncio.create_task(file_reporter(websocket))

    with open(os.path.join("code", DEFAULT_FILE), "r") as f:
        contents = f.read()

    await websocket.send_json({
        'response': 'filecontents',
        'filename': DEFAULT_FILE,
        'data': contents
    })

    while True:
        try:
            data = await websocket.receive_json()
            print(websocket)
            print(data)
            if not 'request' in data:
                await websocket.send_json({
                    'response': 'error',
                    'description': 'No request was made'
                })
                continue

            if data['request'] == 'run':
                if runner_coro:
                    runner_coro.cancel()
                await websocket.send_json({
                    'response': 'starting',
                })
                runner_coro = asyncio.create_task(
                    run_code(websocket, data['data']))
                continue

            if data['request'] == 'terminate':
                if runner_coro:
                    runner_coro.cancel()
                continue

            if data['request'] == 'filecontents':
                filename = data['data']
                if not os.path.isfile(os.path.join("code", filename)):
                    await websocket.send_json({
                        'response': 'error',
                        'description': 'File does not exist'
                    })
                with open(os.path.join("code", filename), "r") as f:
                    contents = f.read()
                await websocket.send_json({
                    'response': 'filecontents',
                    'filename': filename,
                    'data': contents
                })
                continue
            
            if data['request'] == 'save':
                filename = data['filename']
                with open(os.path.join("code", filename), "w") as f:
                    f.write(data["data"])
                continue

        except asyncio.CancelledError:
            info("Websocket disconnected, cleaning up...")
            if runner_coro != None:
                runner_coro.cancel()
            if reporter_coro != None:
                reporter_coro.cancel()


@app.route("/")
async def index():
    return await render_template("repl.html")

if __name__ == "__main__":
    logging.basicConfig(encoding='utf-8', level=logging.DEBUG)
    app.run("0.0.0.0", 5000, True)
