
const queryString = window.location.search;
const urlParams = new URLSearchParams(queryString);

const workingDir = urlParams.get('working_dir');
const initFile = urlParams.get('init_file');
const downloadExt = urlParams.get('download_ext');


var editor = ace.edit("editor");
var modelist = ace.require("ace/ext/modelist")
editor.setTheme("ace/theme/dracula");
editor.session.setMode("ace/mode/julia");

var term = new Terminal();
term.open(document.getElementById('output'));

const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);

var ws = new WebSocket('ws://' + document.domain + ':' + location.port + '/api/v2/ws');

var outputcontainer = document.getElementById("output");

var filelistcontainer = document.getElementById("filelist");

var selectfilebutton = document.getElementById("selectfilebutton");

var workingfile = "";

ws.onopen = function (event) {
    ws.send(JSON.stringify({ request: "workingdir", data: workingDir }));
    requestFile(initFile);
}


ws.onmessage = function (event) {
    console.log(event.data);
    dataobj = JSON.parse(event.data);
    /*
    if (dataobj["response"] == "stdout") {
        dataobj["data"] = dataobj["data"].replaceAll(" ", "&nbsp");
        dataobj["data"] = dataobj["data"].replaceAll("\n", "<br>");
        outputcontainer.innerHTML += dataobj["data"]
    }
    if (dataobj["response"] == "stderr") {
        dataobj["data"] = dataobj["data"].replaceAll(" ", "&nbsp");
        dataobj["data"] = dataobj["data"].replaceAll("\n", "<br>");
        outputcontainer.innerHTML += "<a class='outputerror'>"+dataobj["data"]+"</a>"
    }*/
    if (dataobj["response"] == "stdout" || dataobj["response"] == "stderr") {
        dataobj["data"] = dataobj["data"].replaceAll("\n", "\n\r");
        term.write(dataobj["data"]);
    }
    if (dataobj["response"] == "files") {
        drophtml = "";

        // The first entry of the file list allows the user to create a new file
        drophtml += "<div class='listelem newfile' onclick='requestCreateFile()'>Create new file</div>";

        for (var i in dataobj["data"]) {
            // If the file has the extension downloadExt, trigger download
            if (dataobj["data"][i].endsWith(downloadExt)) {
                drophtml += '<div class="listelem"> <a class="linkleft" href="#" onclick="downloadFile(\'' + 
                    dataobj["data"][i] + '\')">' + dataobj["data"][i] + '</a>' + 
                    '<a class="delete" href="#" onclick="requestDelete(\'' + dataobj["data"][i] + '\')">' +
                    '&#x232B' + '</a>' + '</div>';
            } else {
                // When a file is selected, request the file contents
                //drophtml += '<a href="#" onclick="requestFile(\'' +
                //    dataobj["data"][i] + '\')">' + dataobj["data"][i] + '</a>';

                // This is okay but we need an option to request and also delete a file
                // I suggest something like:

                // Unicode symbol for delete: U+232B

                drophtml += '<div class="listelem"> <a class="linkleft" href="#" onclick="requestFile(\'' + 
                    dataobj["data"][i] + '\')">' + dataobj["data"][i] + '</a>' + 
                    '<a class="delete" href="#" onclick="requestDelete(\'' + dataobj["data"][i] + '\')">' +
                    '&#x232B' + '</a>' + '</div>';
            }
        }
        filelistcontainer.innerHTML = drophtml;
    }
    if (dataobj["response"] == "filecontents") {
        editor.session.setValue(dataobj["data"]);
        workingfile = dataobj["filename"];
        selectfilebutton.innerText = workingfile;
        var mode = modelist.getModeForPath(dataobj["filename"]).mode;
        editor.session.setMode(mode);
    }
    if (dataobj["response"] == "finished") {
        var currentdate = new Date();
        var datetime = currentdate.getDate() + "/"
            + (currentdate.getMonth() + 1) + "/"
            + currentdate.getFullYear() + " @ "
            + currentdate.getHours() + ":"
            + currentdate.getMinutes() + ":"
            + currentdate.getSeconds();
        term.write("[22m[39m[90mFinished with exit code " + dataobj["data"] +  
            " on " + datetime + "[39m\n\r");
    }
    if (dataobj["response"] == "starting") {
        var currentdate = new Date();
        var datetime = currentdate.getDate() + "/"
            + (currentdate.getMonth() + 1) + "/"
            + currentdate.getFullYear() + " @ "
            + currentdate.getHours() + ":"
            + currentdate.getMinutes() + ":"
            + currentdate.getSeconds();

        term.write("[22m[39m[90mStarting execution on " + datetime + "[39m\n\r");
    }
};

fitAddon.fit();

function requestFile(filename) {
    ws.send(JSON.stringify({
        request: "filecontents",
        data: filename
    }))
}

function requestCreateFile() {
    // Ask the user for the filename
    var filename = prompt("Enter the filename");
    if (filename == null) {
        return;
    }
    ws.send(JSON.stringify({
        request: "createfile",
        data: filename
    }))
}

function downloadFile(filename) {
    // Trigger file download using javascript
    var a = document.createElement("a");
    a.href = "http://" + document.domain + ":" + location.port + "/api/v2/download/" + workingDir + "/" + filename;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}

function requestRun() {
    requestSave();
    ws.send(JSON.stringify({
        request: "run",
        data: workingfile
    }));
    fitAddon.fit();
    term.clear();
}

function requestDelete(filename) {
    // ask for confirmation
    if (confirm("Are you sure you want to delete " + filename + "?")) {
        ws.send(JSON.stringify({
            request: "delete",
            data: filename
        }));
    }
    // If the deleted file is the currently open file, open the init file
    if (filename == workingfile) {
        requestFile(initFile);
    }
}

function requestSave() {
    ws.send(JSON.stringify({
        request: "save",
        filename: workingfile,
        data: editor.getValue()
    }))
}

function requestTerminate() {
    ws.send(JSON.stringify({
        request: "terminate"
    }));
    term.write("Forced termination\n\r");
}

function selectFile() {
    document.getElementById("filelist").classList.toggle("show");
}

// Close the dropdown menu if the user clicks outside of it
window.onclick = function (event) {
    if (!event.target.matches('.dropbtn')) {
        var dropdowns = document.getElementsByClassName("dropdown-content");
        var i;
        for (i = 0; i < dropdowns.length; i++) {
            var openDropdown = dropdowns[i];
            if (openDropdown.classList.contains('show')) {
                openDropdown.classList.remove('show');
            }
        }
    }
}