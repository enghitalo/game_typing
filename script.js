// 1. Configuration
const quoteDisplayElement = document.getElementById("quote-display");
const quoteInputElement = document.getElementById("quote-input");
const dropZoneElement = document.getElementById("drop-zone");
const fileListElement = document.getElementById("file-list");

// You can change this text to whatever you want
const textToType =
  "The quick brown fox jumps over the lazy dog.\nProgramming is the art of telling another human what one wants the computer to do.\n\tSimplicity is the soul of efficiency.";

// 2. Setup function: Renders the text as individual spans
function renderQuote() {
  quoteDisplayElement.innerHTML = "";
  // Split string into array of characters
  textToType.split("").forEach((character) => {
    const characterSpan = document.createElement("span");
    characterSpan.innerText = character;
    quoteDisplayElement.appendChild(characterSpan);
  });
  // Set initial cursor on first character
  quoteDisplayElement.querySelectorAll("span")[0].classList.add("active");
}

// 3. Logic: Compare input with the text
quoteInputElement.addEventListener("input", () => {
  const arrayQuote = quoteDisplayElement.querySelectorAll("span");
  const arrayValue = quoteInputElement.value.split("");

  // Loop through every character in the display
  arrayQuote.forEach((characterSpan, index) => {
    const character = arrayValue[index];

    // Remove the cursor from everywhere first
    characterSpan.classList.remove("active");

    if (character == null) {
      // Character hasn't been typed yet
      characterSpan.classList.remove("correct");
      characterSpan.classList.remove("incorrect");
    } else if (character === characterSpan.innerText) {
      // Correctly typed
      characterSpan.classList.add("correct");
      characterSpan.classList.remove("incorrect");
    } else {
      // Incorrectly typed
      characterSpan.classList.remove("correct");
      characterSpan.classList.add("incorrect");
    }
  });

  // Add the cursor visual to the next character waiting to be typed
  if (arrayValue.length < arrayQuote.length) {
    arrayQuote[arrayValue.length].classList.add("active");
  }
});

// 4. Quality of Life: Ensure clicking the text focuses the hidden input
quoteDisplayElement.addEventListener("click", () => {
  quoteInputElement.focus();
});

// Initialize
renderQuote();

// 5. Drag & Drop multiple .txt files and list in sidebar
const state = {
  files: [], // {name, size, content}
  selectedIndex: null,
};

function bytesToKB(size) {
  return `${(size / 1024).toFixed(1)} KB`;
}

function renderFileList() {
  fileListElement.innerHTML = "";
  state.files.forEach((f, idx) => {
    const li = document.createElement("li");
    li.className = idx === state.selectedIndex ? "active" : "";
    li.dataset.index = idx;
    li.innerHTML = `<span class="name">${
      f.name
    }</span><span class="size">${bytesToKB(f.size)}</span>`;
    li.addEventListener("click", () => selectFile(idx));
    fileListElement.appendChild(li);
  });
}

function selectFile(index) {
  state.selectedIndex = index;
  renderFileList();
  const content = state.files[index]?.content ?? "";
  // Replace the text to type with file content and re-render
  renderText(content);
}

function renderText(text) {
  quoteDisplayElement.innerHTML = "";
  const chars = text.split("");
  chars.forEach((ch) => {
    const span = document.createElement("span");
    span.innerText = ch;
    quoteDisplayElement.appendChild(span);
  });
  quoteInputElement.value = "";
  const first = quoteDisplayElement.querySelector("span");
  if (first) first.classList.add("active");
}

function handleFiles(files) {
  const txtFiles = Array.from(files).filter(
    (f) => f.type === "text/plain" || f.name.toLowerCase().endsWith(".txt")
  );
  if (txtFiles.length === 0) return;

  const readers = txtFiles.map(
    (file) =>
      new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () =>
          resolve({ name: file.name, size: file.size, content: reader.result });
        reader.onerror = reject;
        reader.readAsText(file);
      })
  );

  Promise.all(readers).then((results) => {
    state.files = results;
    state.selectedIndex = 0;
    renderFileList();
    selectFile(0);
  });
}

// Drop zone interactions
dropZoneElement.addEventListener("click", () => {
  // Create a hidden file input to support click-to-upload
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".txt,text/plain";
  input.multiple = true;
  input.addEventListener("change", (e) => handleFiles(e.target.files));
  input.click();
});

["dragenter", "dragover"].forEach((evt) => {
  dropZoneElement.addEventListener(evt, (e) => {
    e.preventDefault();
    e.stopPropagation();
    dropZoneElement.classList.add("dragover");
  });
});

["dragleave", "drop"].forEach((evt) => {
  dropZoneElement.addEventListener(evt, (e) => {
    e.preventDefault();
    e.stopPropagation();
    dropZoneElement.classList.remove("dragover");
  });
});

dropZoneElement.addEventListener("drop", (e) => {
  const dt = e.dataTransfer;
  if (!dt) return;
  const files = dt.files;
  handleFiles(files);
});
