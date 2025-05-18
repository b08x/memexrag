// public/js/radiology_translate.js

document.addEventListener('DOMContentLoaded', () => {
  // --- Element Selectors ---
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');

  // Text Translation Tab Elements
  const translateTextBtn = document.getElementById('translateBtn'); // Renamed for clarity
  const textTranslationLoadingIndicator = document.getElementById('loadingIndicator');
  const actualTranslatedTextDiv = document.getElementById('actualTranslation'); // Where translated text goes
  const originalTextInput = document.getElementById('originalText'); // Textarea for manual input / doc output
  const translatedTextContainer = document.getElementById('translatedTextContainer'); // General container for results
  const originalLangLabel = document.getElementById('originalLangLabel');
  const translatedLangLabel = document.getElementById('translatedLangLabel');
  const originalWordCount = document.getElementById('originalWordCount');
  const translatedWordCount = document.getElementById('translatedWordCount');
  const clearOriginalBtn = document.getElementById('clearOriginalBtn');
  const sourceLangSelect = document.getElementById('sourceLangSelect');
  const targetLangSelect = document.getElementById('targetLangSelect');

  // Document Upload Specific Elements
  const uploadDocBtn = document.getElementById('uploadDocBtn');
  const docUploadInput = document.getElementById('docUploadInput'); // Actual <input type="file">
  const docUploadProgress = document.getElementById('docUploadProgress'); // Progress bar container for DOC UPLOAD
  const docUploadBar = document.getElementById('docUploadBar');         // The bar itself for DOC UPLOAD
  const docUploadPercent = document.getElementById('docUploadPercent');   // Percentage text for DOC UPLOAD
  const docProcessingSpinner = document.getElementById('docProcessingSpinner'); // New spinner for server-side processing
  const uploadStatusIndicator = document.getElementById('uploadStatusIndicator'); // General status messages for upload/processing
  const extractedDocContentContainer = document.getElementById('extractedDocContentContainer'); // To display extracted structure

  // Media Analysis Tab Elements (mostly placeholders, adapt if needed)
  const mediaUpload = document.getElementById('mediaUpload');
  const previewContainer = document.getElementById('previewContainer');
  const previewImage = document.getElementById('previewImage');
  const previewVideo = document.getElementById('previewVideo');
  const dropZoneOverlay = document.getElementById('dropZoneOverlay');
  const clearMediaBtn = document.getElementById('clearMediaBtn');
  const mediaLoadingIndicator = document.getElementById('mediaLoadingIndicator');
  const mediaResultsPlaceholder = document.getElementById('mediaResultsPlaceholder');
  const actualMediaResults = document.getElementById('actualMediaResults');
  const extractTextBtn = document.getElementById('extractTextBtn');
  const analyzeUiBtn = document.getElementById('analyzeUiBtn');
  const translateMediaBtn = document.getElementById('translateMediaBtn');
  const copyResultsBtn = document.getElementById('copyResultsBtn');
  const downloadResultsBtn = document.getElementById('downloadResultsBtn');
  // const analysisResultsContainer = document.getElementById('analysisResults'); // Defined but not used in provided snippet

  // --- Tab Switching ---
  tabButtons.forEach(button => {
    button.addEventListener('click', function() {
      tabButtons.forEach(btn => {
        btn.classList.remove('active', 'text-white', 'bg-slate-800', 'border-b-3', 'border-emerald-500');
        btn.classList.add('text-slate-400', 'hover:text-white');
      });
      tabContents.forEach(content => content.classList.remove('active'));
      this.classList.add('active', 'text-white', 'bg-slate-800', 'border-b-3', 'border-emerald-500');
      this.classList.remove('text-slate-400', 'hover:text-white');
      const tabId = this.getAttribute('data-tab');
      const activeTabContent = document.getElementById(tabId);
      if (activeTabContent) activeTabContent.classList.add('active');
    });
  });
  const initialActiveButton = document.querySelector('.tab-button.active') || document.querySelector('.tab-button');
  if (initialActiveButton) {
    initialActiveButton.click(); // Simulate click to set initial state
  }


  // --- Word Count Functionality ---
  function updateWordCount(textAreaOrDiv, countElement) {
    if (!textAreaOrDiv || !countElement) return;
    const textSource = textAreaOrDiv.tagName === 'TEXTAREA' ? textAreaOrDiv.value : textAreaOrDiv.innerText;
    const text = textSource.trim();
    const words = text.length > 0 ? text.split(/\s+/).filter(Boolean).length : 0;
    countElement.textContent = `${words} words`;
  }

  // --- Text Translation Tab Functionality (Manual Text Input) ---
  function updateLangLabels() {
    if (sourceLangSelect && originalLangLabel) {
      originalLangLabel.textContent = sourceLangSelect.options[sourceLangSelect.selectedIndex].text;
    }
    if (targetLangSelect && translatedLangLabel) {
      translatedLangLabel.textContent = targetLangSelect.options[targetLangSelect.selectedIndex].text;
    }
  }
  if (sourceLangSelect) sourceLangSelect.addEventListener('change', updateLangLabels);
  if (targetLangSelect) targetLangSelect.addEventListener('change', updateLangLabels);

  if (translateTextBtn) {
    translateTextBtn.addEventListener('click', function() {
      if (!originalTextInput || !originalTextInput.value.trim()) {
        alert('Please enter text to translate or upload a document first.');
        return;
      }
      if (textTranslationLoadingIndicator && actualTranslatedTextDiv && translatedTextContainer) {
        textTranslationLoadingIndicator.classList.remove('hidden');
        textTranslationLoadingIndicator.classList.add('loading');
        textTranslationLoadingIndicator.innerHTML = '<i class="fas fa-spinner fa-spin text-3xl mr-2"></i> Translating...';
        actualTranslatedTextDiv.classList.add('hidden');
        actualTranslatedTextDiv.innerHTML = ''; // Clear previous results
        if (translatedWordCount) translatedWordCount.textContent = '0 words';
      }

      const sourceLang = sourceLangSelect ? sourceLangSelect.value : 'en';
      const targetLang = targetLangSelect ? targetLangSelect.value : 'ta';
      const textToTranslate = originalTextInput.value;

      fetch('/memexrag/proxy/translate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({
          text: textToTranslate,
          source_language: sourceLang,
          target_language: targetLang
        })
      })
      .then(response => {
        if (!response.ok) {
          return response.json().catch(() => ({ error: `Translation service responded with status ${response.status}` }))
            .then(errData => { throw new Error(errData.error || `HTTP error ${response.status}`); });
        }
        return response.json();
      })
      .then(data => {
        if (textTranslationLoadingIndicator && actualTranslatedTextDiv) {
          textTranslationLoadingIndicator.classList.add('hidden');
          textTranslationLoadingIndicator.classList.remove('loading');
          actualTranslatedTextDiv.classList.remove('hidden');
          actualTranslatedTextDiv.innerHTML = `<p class="${targetLang === 'ta' ? 'tamil-font' : ''}">${data.translated_text || 'No translation returned.'}</p>`;
          updateWordCount(actualTranslatedTextDiv, translatedWordCount);
        }
      })
      .catch(error => {
        console.error('Text Translation Error:', error);
        alert(`Translation failed: ${error.message}`);
        if (textTranslationLoadingIndicator) {
          textTranslationLoadingIndicator.classList.remove('hidden', 'loading');
          textTranslationLoadingIndicator.innerHTML = '<i class="fas fa-exclamation-triangle text-red-500 text-4xl mb-3"></i><p>Translation failed.</p>';
        }
        if (actualTranslatedTextDiv) actualTranslatedTextDiv.classList.add('hidden');
      });
    });
  }

  if (originalTextInput && originalWordCount) {
    originalTextInput.addEventListener('input', () => updateWordCount(originalTextInput, originalWordCount));
  }

  if (clearOriginalBtn && originalTextInput && originalWordCount) {
    clearOriginalBtn.addEventListener('click', () => {
      originalTextInput.value = '';
      updateWordCount(originalTextInput, originalWordCount);
      if (actualTranslatedTextDiv) {
        actualTranslatedTextDiv.innerHTML = '';
        actualTranslatedTextDiv.classList.add('hidden');
      }
      if (textTranslationLoadingIndicator) {
        textTranslationLoadingIndicator.classList.remove('hidden', 'loading');
        textTranslationLoadingIndicator.innerHTML = '<i class="fas fa-language text-4xl mb-3"></i><p>Translation will appear here</p>';
      }
      if (translatedTextContainer) translatedTextContainer.innerHTML = ''; // May be redundant
      if (translatedWordCount) translatedWordCount.textContent = '0 words';
      if (uploadStatusIndicator) uploadStatusIndicator.innerHTML = '';
      if (extractedDocContentContainer) extractedDocContentContainer.innerHTML = ''; // Clear extracted content display
      resetDocUploadUIState();
    });
  }

  // --- Document Upload and Synchronous Processing Functionality ---
  if (uploadDocBtn && docUploadInput) {
    uploadDocBtn.addEventListener('click', () => {
      if (uploadStatusIndicator) uploadStatusIndicator.innerHTML = ''; // Clear previous status
      if (extractedDocContentContainer) extractedDocContentContainer.innerHTML = ''; // Clear previous results
      docUploadInput.click(); // Trigger file input
    });

    docUploadInput.addEventListener('change', (event) => {
      const file = event.target.files[0];
      if (file) {
        const allowedTypes = [
          'text/plain', 'application/pdf',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
          'application/msword' // .doc (less common, but might be needed)
        ];
        if (!allowedTypes.includes(file.type)) {
          alert('Invalid file type. Please upload .txt, .pdf, .doc, or .docx files.');
          resetDocUploadInput();
          return;
        }
        // Clear original text input when a file is selected for processing
        if (originalTextInput) originalTextInput.value = '';
        if (originalWordCount) updateWordCount(originalTextInput, originalWordCount);
        if (actualTranslatedTextDiv) actualTranslatedTextDiv.innerHTML = '';


        handleSynchronousDocConversion(file);
        resetDocUploadInput(); // Reset file input after selection
      }
    });
  }

  function resetDocUploadInput() {
    if (docUploadInput) docUploadInput.value = ''; // Clears the selected file
  }

  function resetDocUploadUIState() {
    if (docUploadProgress) docUploadProgress.classList.add('hidden');
    if (docUploadBar) docUploadBar.style.width = '0%';
    if (docUploadPercent) docUploadPercent.textContent = '0%';
    if (docProcessingSpinner) docProcessingSpinner.classList.add('hidden');
    if (uploadDocBtn) {
        uploadDocBtn.disabled = false;
        uploadDocBtn.classList.remove('opacity-50', 'cursor-not-allowed');
        uploadDocBtn.innerHTML = '<i class="fas fa-upload mr-2"></i><span>Upload Document</span>';
    }
    if (originalTextInput) originalTextInput.readOnly = false;
  }


  function showDocProcessingStatus(message, isProcessing = false, isError = false) {
    if (uploadStatusIndicator) {
        let iconClass = 'fas fa-info-circle';
        let textColor = 'text-blue-700'; // Default to info
        if (isProcessing) {
            iconClass = 'fas fa-spinner fa-spin';
            // textColor might remain blue or change based on preference
        } else if (isError) {
            iconClass = 'fas fa-exclamation-triangle';
            textColor = 'text-red-500';
        } else if (message && !isError && !isProcessing) { // Success message
            iconClass = 'fas fa-check-circle';
            textColor = 'text-emerald-500';
        }

        uploadStatusIndicator.innerHTML = `<i class="${iconClass} ${textColor} mr-2"></i><span class="${textColor}">${message}</span>`;

        if (!isProcessing && !isError && message) { // Auto-clear success message
            setTimeout(() => {
                if (uploadStatusIndicator.innerHTML.includes(message)) { // Check if it's still the same message
                    uploadStatusIndicator.innerHTML = '';
                }
            }, 7000); // Increased duration for success messages
        }
    }
  }


  async function handleSynchronousDocConversion(file) {
    const formData = new FormData();
    formData.append('file', file);

    // Reset UI for new processing
    if (docUploadProgress) docUploadProgress.classList.remove('hidden');
    if (docUploadBar) docUploadBar.style.width = '0%';
    if (docUploadPercent) docUploadPercent.textContent = '0%';
    if (docProcessingSpinner) docProcessingSpinner.classList.add('hidden'); // Ensure spinner is hidden initially
    if (uploadStatusIndicator) uploadStatusIndicator.innerHTML = '';
    if (extractedDocContentContainer) extractedDocContentContainer.innerHTML = '';


    showDocProcessingStatus(`Uploading ${file.name}...`, true);
    if (uploadDocBtn) {
        uploadDocBtn.disabled = true;
        uploadDocBtn.classList.add('opacity-50', 'cursor-not-allowed');
        uploadDocBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i><span>Uploading...</span>';
    }
    if(originalTextInput) originalTextInput.readOnly = true;


    const xhr = new XMLHttpRequest();
    // Ensure this endpoint '/convert_document' matches your new synchronous Sinatra route
    xhr.open('POST', '/convert_document', true);

    xhr.upload.onprogress = function(e) {
      if (e.lengthComputable) {
        const percentComplete = (e.loaded / e.total) * 100;
        if (docUploadBar) docUploadBar.style.width = percentComplete + '%';
        if (docUploadPercent) docUploadPercent.textContent = Math.round(percentComplete) + '%';
        if (percentComplete === 100) {
            showDocProcessingStatus(`Processing ${file.name} on server...`, true);
            if (docProcessingSpinner) docProcessingSpinner.classList.remove('hidden'); // Show server processing spinner
            if (uploadDocBtn) uploadDocBtn.innerHTML = '<i class="fas fa-cog fa-spin mr-2"></i><span>Processing...</span>';
        }
      }
    };

    xhr.onload = function() {
      if (docUploadProgress) docUploadProgress.classList.add('hidden');
      if (docProcessingSpinner) docProcessingSpinner.classList.add('hidden');
      resetDocUploadUIState(); // Re-enable button, etc.

      if (xhr.status === 200) {
        try {
          const response = JSON.parse(xhr.responseText);
          if (response.status === 'SUCCESS') {
            showDocProcessingStatus(`Successfully processed ${file.name}. Task ID: ${response.task_id}`, false);
            displayExtractedDocumentStructure(response, file.name); // New function to display rich structure

            // Populate originalText with a primary text content if available
            const primaryText = findPrimaryTextFromStructure(response.directory_structure, response.output_path_base_for_js_access); // You'll need to implement or decide this
            if (originalTextInput && primaryText) {
                originalTextInput.value = primaryText;
                updateWordCount(originalTextInput, originalWordCount);
                // Optionally trigger translation automatically if originalText is populated
                // if (translateTextBtn) translateTextBtn.click();
            } else if (originalTextInput) {
                originalTextInput.value = "No primary text content found in document, or document is not text-based. See extracted structure.";
                updateWordCount(originalTextInput, originalWordCount);
            }

          } else {
            showDocProcessingStatus(`Processing Error: ${response.error || 'Unknown error from server.'}`, false, true);
            if (originalTextInput) originalTextInput.value = `Failed to process document: ${response.error || 'Unknown error'}`;
          }
        } catch (e) {
          console.error("Failed to parse server response:", e, xhr.responseText);
          showDocProcessingStatus('Error: Could not understand server response.', false, true);
          if (originalTextInput) originalTextInput.value = 'Error parsing server response.';
        }
      } else {
        let errorMsg = `Server error: ${xhr.status} ${xhr.statusText}`;
        try { const errResp = JSON.parse(xhr.responseText); if (errResp && errResp.error) errorMsg = errResp.error; } catch (e) { /*ignore*/ }
        showDocProcessingStatus(errorMsg, false, true);
        if (originalTextInput) originalTextInput.value = `Server error: ${errorMsg}`;
      }
      updateWordCount(originalTextInput, originalWordCount); // Update count based on what was populated
    };

    xhr.onerror = function() {
      if (docUploadProgress) docUploadProgress.classList.add('hidden');
      if (docProcessingSpinner) docProcessingSpinner.classList.add('hidden');
      resetDocUploadUIState();
      showDocProcessingStatus('Network error during upload/processing.', false, true);
      if (originalTextInput) originalTextInput.value = 'Network error.';
      updateWordCount(originalTextInput, originalWordCount);
    };

    xhr.send(formData);
  }

  // --- Function to display the extracted document structure ---
  function displayExtractedDocumentStructure(data, originalFileName) {
    if (!extractedDocContentContainer) return;

    let htmlContent = `<h3 class="text-lg font-semibold mb-2 text-slate-700">Extracted Structure for: ${escapeHTML(originalFileName)}</h3>`;
    if (data.structure_metadata) {
        htmlContent += `<p class="text-sm text-slate-600">Total Files: ${data.structure_metadata.total_files || 0}</p>`;
        if (data.structure_metadata.referenced_artifacts_count > 0) {
            htmlContent += `<p class="text-sm text-slate-600">Referenced Artifacts Dirs: ${data.structure_metadata.referenced_artifacts_directories.join(', ') || 'None'}</p>`;
        }
    }
    htmlContent += '<ul class="list-disc pl-5 mt-2 text-sm text-slate-600">';
    htmlContent += renderDirectoryStructure(data.directory_structure, "");
    htmlContent += '</ul>';

    // Add raw JSON view for debugging or power users
    htmlContent += `<div class="mt-4">
                      <button id="toggleRawJsonBtn" class="text-xs text-blue-500 hover:underline">Show Raw JSON Structure</button>
                      <pre id="rawJsonOutput" class="hidden bg-slate-800 text-slate-200 p-2 rounded-md overflow-x-auto text-xs mt-1">${escapeHTML(JSON.stringify(data, null, 2))}</pre>
                   </div>`;

    extractedDocContentContainer.innerHTML = htmlContent;

    const toggleBtn = document.getElementById('toggleRawJsonBtn');
    const rawJsonPre = document.getElementById('rawJsonOutput');
    if (toggleBtn && rawJsonPre) {
        toggleBtn.addEventListener('click', () => {
            rawJsonPre.classList.toggle('hidden');
            toggleBtn.textContent = rawJsonPre.classList.contains('hidden') ? 'Show Raw JSON Structure' : 'Hide Raw JSON Structure';
        });
    }
  }

  function renderDirectoryStructure(structure, currentPath) {
      let listHtml = '';
      if (!structure) return '';

      // Files at the current level
      if (structure.files && structure.files.length > 0) {
          structure.files.forEach(file => {
              const filePath = currentPath ? `${currentPath}/${file}` : file;
              listHtml += `<li><i class="fas fa-file mr-2 text-slate-500"></i>${escapeHTML(file)}</li>`;
          });
      }

      // Directories at the current level
      if (structure.directories) {
          for (const dirName in structure.directories) {
              if (structure.directories.hasOwnProperty(dirName)) {
                  const dirPath = currentPath ? `${currentPath}/${dirName}` : dirName;
                  let specialClass = '';
                  if (structure.directories[dirName].is_referenced_artifacts) {
                      specialClass = 'text-purple-600 font-semibold'; // Example styling
                  }
                  listHtml += `<li>
                                 <i class="fas fa-folder mr-2 ${structure.directories[dirName].is_referenced_artifacts ? 'text-purple-500' : 'text-yellow-500'}"></i>
                                 <span class="${specialClass}">${escapeHTML(dirName)}</span>
                                 <ul class="list-disc pl-5">
                                   ${renderDirectoryStructure(structure.directories[dirName], dirPath)}
                                 </ul>
                               </li>`;
              }
          }
      }
      return listHtml;
  }

  // Helper to find some text content to populate the main textarea.
  // This is a simple version; you might want more sophisticated logic.
  function findPrimaryTextFromStructure(structure, basePath, preferredExtensions = ['.txt', '.md']) {
      if (!structure) return null;
      let foundText = null;

      function search(currentStruct, currentDiskPath) {
          if (foundText) return; // Stop if already found

          if (currentStruct.files) {
              for (const file of currentStruct.files) {
                  if (preferredExtensions.some(ext => file.toLowerCase().endsWith(ext))) {
                      // In a real scenario, you'd fetch this content or have it in the structure.
                      // Since this JS runs in the browser, it CANNOT access server file system directly.
                      // The `DoclingConverterTool` response should ideally include content for main text files,
                      // or Sinatra should provide another endpoint to fetch specific file content from the `output_path`.
                      // For now, this function can only return a *path* or *name* if content isn't in the JSON.
                      // Let's assume `DoclingConverterTool` might add a `primary_content` field for simplicity.
                      // Or, one of the files in the JSON from server has its content.
                      // For DEMO, this will just return a placeholder.
                      // To actually get content, you'd need another fetch call to Sinatra.
                      // For now, we will assume it's embedded or this function should change to pick a file to *request*
                      // For this example, let's assume the JSON response ITSELF contains content for SOME files
                      // and `DoclingConverterTool` puts it there for *.txt or *.md files.
                      if (typeof file === 'object' && file.content) { // Hypothetical: file object has content
                          foundText = file.content;
                          return;
                      }
                      // If not embedded, we can't get it here directly.
                      // foundText = `Content of ${currentDiskPath}/${file} would be displayed here.`;
                      // return;
                  }
              }
          }
          if (foundText) return;

          if (currentStruct.directories) {
              for (const dirName in currentStruct.directories) {
                  search(currentStruct.directories[dirName], `${currentDiskPath}/${dirName}`);
                  if (foundText) return;
              }
          }
      }
      // For this function to be useful, the JSON needs file content or you need another endpoint
      // Let's assume the server's response (`data` in `displayExtractedDocumentStructure`) under
      // `directory_structure` might have file objects with a `content` property for text files.
      // If not, this function needs to be rethought for a client-side JS context.
      // search(structure, ""); // basePath is for constructing full paths IF making further requests
      // This is a conceptual issue: the JS client can't read from `response.output_path` on the server.
      // The `DoclingConverterTool` should include the actual text of the primary file in its JSON response,
      // or a limited number of text files.
      // Let's look for a file named 'input_20250516-1-4u2zul-embedded.md' or similar for example.
      let primaryContent = null;
      function findEmbeddedContent(currentStructure) {
        if (primaryContent) return;
        if (currentStructure.files) {
            for (const file of currentStructure.files) {
                // This part is tricky: The server response from the TOOL needs to include the content.
                // The `files` array in the tool's `directory_structure` are just names.
                // The `MemexRAG::Processors::DoclingConverter#store_extraction_results_as_json`
                // DOES embed content for non-binary files. So, the JSON from Sinatra will have it.

                // We need to traverse the structure from the `data.directory_structure` passed to displayExtracted...
                // Let's refine `findPrimaryTextFromStructure`
                // This is still a stub, assuming the `data.directory_structure` contains actual file content.
                // A better way: the Sinatra route could identify the primary text and send it as a specific field.
            }
        }
        if (currentStructure.directories) {
            for (const dirName in currentStructure.directories) {
                findEmbeddedContent(currentStructure.directories[dirName]);
                if (primaryContent) return;
            }
        }
      }
      // Let's simplify: The Sinatra route should identify and return the primary text.
      // Assuming `data.primary_text_content` is now populated by the Sinatra route '/convert_document'
      // if (data && data.primary_text_content) {
      //    return data.primary_text_content;
      // }
      // Fallback:
      return "Primary text content would be shown here if made available directly in server response.";

  }

  function escapeHTML(str) {
      return str.replace(/[&<>'"]/g,
        tag => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;',
            "'": '&#39;', '"': '&quot;'
        }[tag] || tag)
      );
  }


  // --- Media Analysis Tab Functionality (Placeholders/Simulated) ---
  function handleFileSelectionMedia(file) {
    if (!file) return;
    if (!file.type.match('image.*') && !file.type.match('video.*')) {
      alert('Please select an image or video file for media analysis.');
      return;
    }
    const reader = new FileReader();
    reader.onload = function(e) {
      if (!previewImage || !previewVideo || !previewContainer || !dropZoneOverlay || !actualMediaResults || !mediaResultsPlaceholder || !mediaLoadingIndicator) return;
      previewImage.src = '#'; previewVideo.src = '#';
      previewImage.style.display = 'none'; previewVideo.style.display = 'none';
      actualMediaResults.classList.add('hidden');
      mediaResultsPlaceholder.classList.remove('hidden');
      mediaLoadingIndicator.classList.add('hidden');
      if (file.type.match('image.*')) { previewImage.src = e.target.result; previewImage.style.display = 'block'; }
      else if (file.type.match('video.*')) { previewVideo.src = e.target.result; previewVideo.style.display = 'block'; }
      previewContainer.classList.add('has-preview');
      dropZoneOverlay.style.display = 'none';
    };
    reader.onerror = () => alert('Error reading media file.');
    reader.readAsDataURL(file);
  }

  if (mediaUpload) {
    mediaUpload.addEventListener('change', (e) => handleFileSelectionMedia(e.target.files[0]));
  }

  if (previewContainer) { // Drag and Drop for Media
    previewContainer.addEventListener('dragover', function(e) { e.preventDefault(); this.classList.add('border-emerald-500', 'bg-slate-700'); if (dropZoneOverlay) dropZoneOverlay.style.display = 'flex'; });
    previewContainer.addEventListener('dragleave', function(e) { e.preventDefault(); this.classList.remove('border-emerald-500', 'bg-slate-700'); if (dropZoneOverlay) dropZoneOverlay.style.display = 'none'; });
    previewContainer.addEventListener('drop', function(e) {
      e.preventDefault();
      this.classList.remove('border-emerald-500', 'bg-slate-700');
      if (dropZoneOverlay) dropZoneOverlay.style.display = 'none';
      if (e.dataTransfer.files.length) {
        handleFileSelectionMedia(e.dataTransfer.files[0]);
        if (mediaUpload) mediaUpload.value = ''; // Clear file input
      }
    });
  }

  if (clearMediaBtn) {
    clearMediaBtn.addEventListener('click', function() {
      if (mediaUpload) mediaUpload.value = '';
      if (previewImage) { previewImage.src = '#'; previewImage.style.display = 'none'; }
      if (previewVideo) { previewVideo.src = '#'; previewVideo.style.display = 'none'; }
      if (previewContainer) previewContainer.classList.remove('has-preview');
      if (dropZoneOverlay) dropZoneOverlay.style.display = 'flex'; // Show dropzone text again
      if (actualMediaResults) { actualMediaResults.innerHTML = ''; actualMediaResults.classList.add('hidden'); }
      if (mediaResultsPlaceholder) mediaResultsPlaceholder.classList.remove('hidden');
      if (mediaLoadingIndicator) mediaLoadingIndicator.classList.add('hidden');
    });
  }

  function simulateMediaAnalysis(analysisType) {
    if (!mediaLoadingIndicator || !actualMediaResults || !mediaResultsPlaceholder) return;
    mediaLoadingIndicator.classList.remove('hidden');
    actualMediaResults.classList.add('hidden');
    mediaResultsPlaceholder.classList.add('hidden');
    setTimeout(() => {
      mediaLoadingIndicator.classList.add('hidden');
      actualMediaResults.classList.remove('hidden');
      let resultText = `Simulated result for ${analysisType}:\n`;
      if (analysisType === 'ocr') resultText += "Extracted Text: Patient ID: 12345, Name: John Doe, Finding: Fracture detected in left tibia.";
      else if (analysisType === 'ui') resultText += "UI Element Analysis: Button 'Save' found at (100,200). Input field 'Patient Name' at (50,50).";
      else if (analysisType === 'translate') resultText += "Translated Text (Tamil): நோயாளி ஐடி: 12345, பெயர்: ஜான் டோ, கண்டுபிடிப்பு: இடது திபியாவில் எலும்பு முறிவு கண்டறியப்பட்டது.";
      actualMediaResults.textContent = resultText;
    }, 2000);
  }

  if (extractTextBtn) extractTextBtn.addEventListener('click', () => simulateMediaAnalysis('ocr'));
  if (analyzeUiBtn) analyzeUiBtn.addEventListener('click', () => simulateMediaAnalysis('ui'));
  if (translateMediaBtn) translateMediaBtn.addEventListener('click', () => simulateMediaAnalysis('translate'));

  if (copyResultsBtn && actualMediaResults) {
    copyResultsBtn.addEventListener('click', function() {
      navigator.clipboard.writeText(actualMediaResults.textContent)
        .then(() => alert('Results copied to clipboard!'))
        .catch(err => alert('Failed to copy results: ' + err));
    });
  }

  if (downloadResultsBtn && actualMediaResults) {
    downloadResultsBtn.addEventListener('click', function() {
      const blob = new Blob([actualMediaResults.textContent], { type: 'text/plain' });
      const anchor = document.createElement('a');
      anchor.download = 'analysis_results.txt';
      anchor.href = window.URL.createObjectURL(blob);
      anchor.click();
      window.URL.revokeObjectURL(anchor.href);
    });
  }

  // Sample Image Loading (Placeholder)
  window.loadSampleImage = function(type) {
    if (!previewImage || !previewVideo || !previewContainer || !dropZoneOverlay || !clearMediaBtn) return;
    let sampleImageUrl = '', altText = '';
    const placeholderBase = 'https://placehold.co/600x400/1e293b/e2e8f0/png?text='; // Using PNG for broader compatibility
    switch (type) {
      case 'ris_login': sampleImageUrl = `${placeholderBase}RIS+Login`; altText = 'RIS Login Screen'; break;
      case 'pacs_config': sampleImageUrl = `${placeholderBase}PACS+Config`; altText = 'PACS Configuration'; break;
      case 'worklist_error': sampleImageUrl = `${placeholderBase}Worklist+Error`; altText = 'Worklist Error Message'; break;
      case 'dicom_viewer': sampleImageUrl = `${placeholderBase}DICOM+Viewer`; altText = 'DICOM Image Viewer'; break;
      default: console.warn('Unknown sample image type:', type); return;
    }
    clearMediaBtn.click(); // Clear previous media
    previewImage.src = sampleImageUrl;
    previewImage.alt = altText;
    previewImage.style.display = 'block';
    previewVideo.style.display = 'none'; previewVideo.src = '#';
    previewContainer.classList.add('has-preview');
    dropZoneOverlay.style.display = 'none';
    if (actualMediaResults) actualMediaResults.classList.add('hidden');
    if (mediaResultsPlaceholder) mediaResultsPlaceholder.classList.remove('hidden');
    if (mediaLoadingIndicator) mediaLoadingIndicator.classList.add('hidden');
  };

  // --- Initial Setup ---
  updateLangLabels();
  if (originalTextInput && originalWordCount) updateWordCount(originalTextInput, originalWordCount);
  if (translatedWordCount) translatedWordCount.textContent = '0 words';
  resetDocUploadUIState(); // Ensure clean UI state on load

}); // End DOMContentLoaded