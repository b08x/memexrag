// Wait for the DOM to be fully loaded before executing the script
document.addEventListener('DOMContentLoaded', () => {

  // --- Element Selectors (Consolidated) ---
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');

  // Text Translation Tab Elements
  const translateBtn = document.getElementById('translateBtn');
  const loadingIndicator = document.getElementById('loadingIndicator'); // For TRANSLATION loading
  const actualTranslation = document.getElementById('actualTranslation');
  const originalText = document.getElementById('originalText');
  const translatedTextContainer = document.getElementById('translatedTextContainer');
  const originalLangLabel = document.getElementById('originalLangLabel');
  const translatedLangLabel = document.getElementById('translatedLangLabel');
  const originalWordCount = document.getElementById('originalWordCount');
  const translatedWordCount = document.getElementById('translatedWordCount');
  const clearOriginalBtn = document.getElementById('clearOriginalBtn');
  const sourceLangSelect = document.getElementById('sourceLangSelect');
  const targetLangSelect = document.getElementById('targetLangSelect');
  const uploadDocBtn = document.getElementById('uploadDocBtn');
  const docUploadInput = document.getElementById('docUploadInput');
  const uploadStatusIndicator = document.getElementById('uploadStatusIndicator'); // <<< NEW ELEMENT

  // Media Analysis Tab Elements
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
  const analysisResultsContainer = document.getElementById('analysisResults');


  // --- Tab Switching Functionality ---
  tabButtons.forEach(button => {
    button.addEventListener('click', function() {
      tabButtons.forEach(btn => {
        btn.classList.remove('active', 'text-white', 'bg-slate-800', 'border-b-3', 'border-emerald-500'); // Adjust classes
        btn.classList.add('text-slate-400', 'hover:text-white');
      });
      tabContents.forEach(content => content.classList.remove('active'));
      this.classList.add('active', 'text-white', 'bg-slate-800', 'border-b-3', 'border-emerald-500'); // Apply active styles
      this.classList.remove('text-slate-400', 'hover:text-white');
      const tabId = this.getAttribute('data-tab');
      const activeTabContent = document.getElementById(tabId);
      if (activeTabContent) activeTabContent.classList.add('active');
    });
  });
  const initialActiveButton = document.querySelector('.tab-button.active');
  if (initialActiveButton) {
    const initialTabId = initialActiveButton.getAttribute('data-tab');
    const initialActiveTabContent = document.getElementById(initialTabId);
    if (initialActiveTabContent) initialActiveTabContent.classList.add('active');
  } else {
     const firstTabButton = document.querySelector('.tab-button');
     const firstTabContent = document.querySelector('.tab-content');
     if (firstTabButton && firstTabContent) {
          firstTabButton.classList.add('active', 'text-white', 'bg-slate-800', 'border-b-3', 'border-emerald-500');
          firstTabButton.classList.remove('text-slate-400');
          firstTabContent.classList.add('active');
     }
  }

  // --- Word Count Functionality (Generalized) ---
   function updateWordCount(textAreaOrDiv, countElement) {
      if (!textAreaOrDiv || !countElement) return;
      // Use innerText for divs (like the translation output), value for textareas
      const textSource = textAreaOrDiv.tagName === 'TEXTAREA' ? textAreaOrDiv.value : textAreaOrDiv.innerText;
      const text = textSource.trim();
      const words = text.length > 0 ? text.split(/\s+/).length : 0;
      countElement.textContent = `${words} words`;
   }


  // --- Text Translation Tab Functionality ---
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


  // Manual Text Translation Trigger
   if (translateBtn) {
      translateBtn.addEventListener('click', function() {
        if (!originalText || !originalText.value.trim()) { alert('Please enter text to translate.'); return; }
        if (loadingIndicator && actualTranslation && translatedTextContainer) {
            loadingIndicator.classList.remove('hidden');
            loadingIndicator.classList.add('loading'); // Add spinner class if needed
            loadingIndicator.innerHTML = '<i class="fas fa-spinner fa-spin text-3xl mr-2"></i> Translating...'; // Use spinner here too
            actualTranslation.classList.add('hidden');
            translatedTextContainer.innerHTML = ''; // Clear previous results
            if(translatedWordCount) translatedWordCount.textContent = '0 words';
        }

        // --- Actual Fetch Call ---
        const sourceLang = sourceLangSelect ? sourceLangSelect.value : 'en';
        const targetLang = targetLangSelect ? targetLangSelect.value : 'ta';
        const textToTranslate = originalText.value;

        fetch('/memexrag/proxy/translate', { // Ensure this matches your backend route
             method: 'POST',
             headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json'
             },
             body: JSON.stringify({
                 text: textToTranslate,
                 source_language: sourceLang,
                 target_language: targetLang
             })
         })
         .then(response => {
             if (!response.ok) {
                 // Attempt to parse error JSON, provide fallback
                 return response.json().catch(() => ({ error: `Translation service responded with status ${response.status}` })).then(errData => {
                     throw new Error(errData.error || `HTTP error ${response.status}`);
                 });
             }
             return response.json();
         })
         .then(data => {
             if (loadingIndicator && actualTranslation && translatedTextContainer) {
                 loadingIndicator.classList.add('hidden');
                 loadingIndicator.classList.remove('loading');
                 actualTranslation.classList.remove('hidden');
                 // Populate with actual translated text
                 actualTranslation.innerHTML = `<p class="${targetLang === 'ta' ? 'tamil-font' : ''}">${data.translated_text}</p>`; // Add dynamic font class if needed
                 updateWordCount(actualTranslation, translatedWordCount); // Update count

                 // Re-add highlighting logic if needed here, applied to the new content
                 // const translatedParagraphs = actualTranslation.querySelectorAll('p, li');
                 // ... add listeners ...
             }
         })
         .catch(error => {
             console.error('Translation Error:', error);
             alert(`Translation failed: ${error.message}`);
             // Reset loading indicator to placeholder state
             if (loadingIndicator) {
                 loadingIndicator.classList.remove('hidden');
                 loadingIndicator.classList.remove('loading');
                 loadingIndicator.innerHTML = '<i class="fas fa-exclamation-triangle text-red-500 text-4xl mb-3"></i><p>Translation failed.</p>';
             }
             if (actualTranslation) actualTranslation.classList.add('hidden');
         });
      });
   }


  // Word count for original text
  if (originalText && originalWordCount) {
    originalText.addEventListener('input', () => updateWordCount(originalText, originalWordCount));
  }

  // Clear original text
   if (clearOriginalBtn && originalText && originalWordCount) {
      clearOriginalBtn.addEventListener('click', () => {
        originalText.value = '';
        updateWordCount(originalText, originalWordCount);
        if(actualTranslation) actualTranslation.classList.add('hidden');
        if(loadingIndicator) {
            loadingIndicator.classList.remove('hidden');
            loadingIndicator.classList.remove('loading'); // Ensure loading spinner is stopped
            loadingIndicator.innerHTML = '<i class="fas fa-language text-4xl mb-3"></i><p>Translation will appear here</p>'; // Reset placeholder
        }
        if(translatedTextContainer) translatedTextContainer.innerHTML = '';
        if(translatedWordCount) translatedWordCount.textContent = '0 words';
        if(uploadStatusIndicator) uploadStatusIndicator.innerHTML = ''; // Clear upload status too
      });
   }


  // --- Document Upload Functionality ---
  if (uploadDocBtn && docUploadInput) {
    uploadDocBtn.addEventListener('click', () => {
      if (uploadStatusIndicator) uploadStatusIndicator.innerHTML = '';
      docUploadInput.click();
    });

    docUploadInput.addEventListener('change', (event) => {
      const file = event.target.files[0];
      if (file) {
        console.log('File selected:', file.name, file.type);
        const allowedTypes = [
            'text/plain',
            'application/pdf',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            ];
        if (!allowedTypes.includes(file.type)) {
           alert('Invalid file type. Please upload .txt, .pdf, or .docx files.');
           resetFileInput();
           return;
        }
        handleFileUpload(file);
        resetFileInput();
      }
    });
  }

  function resetFileInput() {
    if(docUploadInput) docUploadInput.value = '';
  }

  // Modified showUploadStatus
  function showUploadStatus(message, isLoading = true, isError = false) {
    console.log(`Upload Status: ${message}`);
    if (uploadStatusIndicator) {
        if (isLoading) {
            uploadStatusIndicator.innerHTML = `<i class="fas fa-spinner fa-spin mr-2"></i><span>${message}</span>`;
            uploadStatusIndicator.classList.remove('text-red-500', 'text-emerald-500');
        } else if (isError) {
            uploadStatusIndicator.innerHTML = `<i class="fas fa-exclamation-triangle text-red-500 mr-2"></i><span class="text-red-500">${message}</span>`;
        } else if (message) {
             uploadStatusIndicator.innerHTML = `<i class="fas fa-check-circle text-emerald-500 mr-2"></i><span class="text-emerald-500">${message}</span>`;
             setTimeout(() => {
                 if (uploadStatusIndicator.innerHTML.includes(message)) {
                      uploadStatusIndicator.innerHTML = '';
                 }
             }, 5000);
        }
        else {
            uploadStatusIndicator.innerHTML = '';
        }
    }
    if (originalText) {
        if (isLoading && message.startsWith('Uploading')) {
             originalText.placeholder = 'Uploading...';
             originalText.value = '';
        } else if (!isLoading && !isError && !originalText.value) {
             originalText.placeholder = 'Enter text to translate or upload a document...';
        }
        originalText.readOnly = isLoading;
    }
    if (uploadDocBtn) {
         uploadDocBtn.disabled = isLoading;
         if (isLoading) {
             uploadDocBtn.classList.add('opacity-50', 'cursor-not-allowed');
             let btnText = 'Processing...';
             if (message.startsWith('Uploading')) btnText = 'Uploading...';
             if (message.startsWith('Retrieving')) btnText = 'Finishing...';
             uploadDocBtn.innerHTML = `<i class="fas fa-spinner fa-spin mr-2"></i><span>${btnText}</span>`;
         } else {
             uploadDocBtn.classList.remove('opacity-50', 'cursor-not-allowed');
             uploadDocBtn.innerHTML = '<i class="fas fa-upload mr-2"></i><span>Upload Document</span>';
         }
    }
    if (translateBtn) translateBtn.disabled = isLoading;
    if (isLoading) {
         if(loadingIndicator) {
             loadingIndicator.classList.remove('hidden');
             loadingIndicator.classList.remove('loading');
             loadingIndicator.innerHTML = '<i class="fas fa-language text-4xl mb-3"></i><p>Translation will appear here</p>';
         }
         if(actualTranslation) actualTranslation.classList.add('hidden');
         if(translatedTextContainer) translatedTextContainer.innerHTML = '';
         if(translatedWordCount) translatedWordCount.textContent = '0 words';
    }
  }


  async function handleFileUpload(file) {
    const formData = new FormData();
    formData.append('file', file);
    showUploadStatus('Uploading document...', true);
    try {
      const uploadResponse = await fetch('/upload_document', { method: 'POST', body: formData });
      if (!uploadResponse.ok) {
        const errorData = await uploadResponse.json().catch(() => ({ error: `Server responded with status ${uploadResponse.status}` }));
        throw new Error(`Upload failed: ${errorData.error || 'Unknown upload error'}`);
      }
      const uploadResult = await uploadResponse.json();
      console.log('Upload submitted:', uploadResult);
      if (uploadResult.task_id && uploadResult.status_endpoint) {
        pollForCompletion(uploadResult.status_endpoint);
      } else {
        throw new Error('Server did not return a valid task ID.');
      }
    } catch (error) {
      console.error('Error during file upload process:', error);
      alert(`Upload Error: ${error.message}`);
      showUploadStatus(`Upload failed: ${error.message}`, false, true);
    }
  }

  async function pollForCompletion(statusEndpoint, interval = 3000, maxAttempts = 40) {
    let attempts = 0;
    const poll = async () => {
      attempts++;
      showUploadStatus(`Processing document (Attempt ${attempts}/${maxAttempts})...`, true);
      if (attempts > maxAttempts) {
         const errorMsg = 'Processing timed out. Please try again.';
         showUploadStatus(errorMsg, false, true);
         alert('Document processing took too long and timed out.');
         return;
      }
      console.log(`Polling status attempt ${attempts}: ${statusEndpoint}`);
      try {
        const statusResponse = await fetch(`/check_task_status?endpoint=${encodeURIComponent(statusEndpoint)}`);
        if (!statusResponse.ok) {
            const errorData = await statusResponse.json().catch(() => ({ error: `Server responded with ${statusResponse.status} (Status check)` }));
            console.warn(`Status check non-OK (HTTP ${statusResponse.status}), retrying... Error: ${errorData.error}`);
            showUploadStatus(`Processing document (Retrying after status error, attempt ${attempts})...`, true);
            setTimeout(poll, interval * 1.5);
            return;
        }
        const statusResult = await statusResponse.json();
        console.log('Poll status:', statusResult.status);
        switch (statusResult.status) {
          case 'SUCCESS':
            if (statusResult.data && statusResult.data.sidekiq_jid) {
              showUploadStatus('Retrieving processed text...', true);
              await retrieveResult(statusResult.data.sidekiq_jid);
            } else { throw new Error('Processing succeeded but job ID is missing.'); }
            break;
          case 'PENDING': case 'STARTED':
            setTimeout(poll, interval);
            break;
          case 'FAILURE':
             throw new Error(`Document processing failed: ${statusResult.error || 'Unknown processing error'}`);
          case 'TIMEOUT':
            throw new Error('Document processing timed out on the server.');
          default:
            console.warn(`Unknown status received: ${statusResult.status}. Retrying...`);
            showUploadStatus(`Processing document (Unknown status '${statusResult.status}', attempt ${attempts})...`, true);
            setTimeout(poll, interval);
        }
      } catch (error) {
        console.error('Error during status polling/result retrieval:', error);
        alert(`Processing Error: ${error.message}`);
        showUploadStatus(`Error: ${error.message}`, false, true);
      }
    };
    poll(); // Start polling
  }

  async function retrieveResult(sidekiqJid) {
    const retryInterval = 10000; // 10 seconds
    const maxRetries = 10;
    let attempts = 0;
    let lastError = null;

    while (attempts < maxRetries) {
        attempts++;
        showUploadStatus(`Finalizing document (Attempt ${attempts}/${maxRetries})...`, true);
        console.log(`Attempt ${attempts}/${maxRetries} to retrieve result for JID: ${sidekiqJid}`);

        try {
            const resultResponse = await fetch(`/retrieve_result?jid=${encodeURIComponent(sidekiqJid)}`);

            if (resultResponse.ok) {
                const resultData = await resultResponse.json();
                if (resultData.success && typeof resultData.text_content === 'string') {
                    if (originalText && originalWordCount) {
                        originalText.value = resultData.text_content;
                        updateWordCount(originalText, originalWordCount);
                        showUploadStatus('Document content extracted successfully!', false);
                    }
                    return; // Success, exit function
                } else {
                    // HTTP 200, but logical error from server (e.g., { success: false, error: "Result not found..." })
                    lastError = new Error(resultData.error || 'Unknown server error after successful HTTP request.');
                    if (lastError.message.includes("Result not found in Redis")) {
                        console.warn(`Result not found (Attempt ${attempts}/${maxRetries}): ${lastError.message}. Retrying...`);
                        if (attempts < maxRetries) {
                            await new Promise(resolve => setTimeout(resolve, retryInterval));
                            continue;
                        }
                    }
                    // For other logical errors, or "Result not found" on last attempt, throw to exit loop.
                    throw lastError;
                }
            } else { // !resultResponse.ok (e.g., 404, 500)
                let errorJson;
                try {
                    errorJson = await resultResponse.json();
                    lastError = new Error(errorJson.error || `Server responded with status ${resultResponse.status}`);
                } catch (e) {
                    lastError = new Error(`Server responded with status ${resultResponse.status} and non-JSON body`);
                }

                if (lastError.message.includes("Result not found in Redis")) {
                    console.warn(`Result not found (HTTP ${resultResponse.status}, Attempt ${attempts}/${maxRetries}): ${lastError.message}. Retrying...`);
                    if (attempts < maxRetries) {
                        await new Promise(resolve => setTimeout(resolve, retryInterval));
                        continue;
                    }
                }
                // For other HTTP errors, or "Result not found" on last attempt, throw to exit loop.
                throw lastError;
            }
        } catch (error) {
            // This catches network errors from fetch(), JSON parsing errors, or errors deliberately thrown above.
            lastError = error; // Store the error
            console.error(`Error on attempt ${attempts}/${maxRetries} for JID ${sidekiqJid}:`, lastError.message);

            // If it's a "Result not found" error and we have retries left, the 'continue' above should have handled it.
            // If it was a "Result not found" error thrown because it was the last attempt, we don't want to retry here.
            if (lastError.message.includes("Result not found in Redis") && attempts < maxRetries) {
                // This path should ideally not be hit if the logic above is correct for "not found" and retries.
                // It implies a "not found" error was caught here before the last attempt.
                console.warn(`Retrying "Result not found" after catch (Attempt ${attempts}/${maxRetries}): ${lastError.message}`);
                await new Promise(resolve => setTimeout(resolve, retryInterval));
                continue;
            } else if (!lastError.message.includes("Result not found in Redis") && attempts < maxRetries) {
                // For other errors (e.g. network) if retries are left.
                console.warn(`Retrying after general error (Attempt ${attempts}/${maxRetries}): ${lastError.message}`);
                await new Promise(resolve => setTimeout(resolve, retryInterval));
                continue;
            }
            // If max retries or if it's an error we decided to throw from the try block (like a non-"not found" server error,
            // or "not found" on the last attempt), this error (`lastError`) will be the one thrown after the loop.
            // Or if it's a "Result not found" that has exhausted retries and was caught here.
        }
    }

    // If loop finishes, all attempts are exhausted.
    console.error(`Failed to retrieve result for JID ${sidekiqJid} after ${maxRetries} attempts. Last error:`, lastError ? lastError.message : "No specific error captured.");

    // Throw the specific timeout error message if the last error was "Result not found"
    if (lastError && lastError.message.includes("Result not found in Redis")) {
        throw new Error("Error: Could not retrieve the document content after multiple attempts. The conversion might have taken too long or an issue occurred. Please try again.");
    }
    // Otherwise, throw the last encountered error or a generic timeout message.
    const finalErrorMessage = lastError ? lastError.message : "Error: Could not retrieve the document content after multiple attempts due to an unknown issue. Please try again.";
    throw new Error(finalErrorMessage.startsWith("Error:") ? finalErrorMessage : `Failed to retrieve result: ${finalErrorMessage}`);
  }


  // --- Media Analysis Tab Functionality ---
  // (Keep existing media analysis code: handleFileSelection, drag/drop, clear, simulateAnalysis, copy/download)
   function handleFileSelection(file) {
        if (!file) return;
        if (!file.type.match('image.*') && !file.type.match('video.*')) { alert('Please select an image or video file'); return; }
        const reader = new FileReader();
        reader.onload = function(e) {
            if (!previewImage || !previewVideo || !previewContainer || !dropZoneOverlay || !actualMediaResults || !mediaResultsPlaceholder || !mediaLoadingIndicator) return;
            previewImage.src = '#'; previewVideo.src = '#';
            previewImage.style.display = 'none'; previewVideo.style.display = 'none';
            actualMediaResults.classList.add('hidden'); mediaResultsPlaceholder.classList.remove('hidden'); mediaLoadingIndicator.classList.add('hidden');
            if (file.type.match('image.*')) { previewImage.src = e.target.result; previewImage.style.display = 'block'; }
            else if (file.type.match('video.*')) { previewVideo.src = e.target.result; previewVideo.style.display = 'block'; }
            previewContainer.classList.add('has-preview'); dropZoneOverlay.style.display = 'none';
        };
        reader.onerror = () => alert('Error reading file.');
        reader.readAsDataURL(file);
    }
   if (mediaUpload) { mediaUpload.addEventListener('change', (e) => handleFileSelection(e.target.files[0])); }
   if (previewContainer) {
        previewContainer.addEventListener('dragover', function(e) { e.preventDefault(); this.classList.add('border-emerald-500', 'bg-slate-700'); if (dropZoneOverlay) dropZoneOverlay.style.borderColor = '#10b981'; });
        previewContainer.addEventListener('dragleave', function(e) { e.preventDefault(); this.classList.remove('border-emerald-500', 'bg-slate-700'); if (dropZoneOverlay) dropZoneOverlay.style.borderColor = ''; });
        previewContainer.addEventListener('drop', function(e) { e.preventDefault(); this.classList.remove('border-emerald-500', 'bg-slate-700'); if (dropZoneOverlay) dropZoneOverlay.style.borderColor = ''; if (e.dataTransfer.files.length) { handleFileSelection(e.dataTransfer.files[0]); if(mediaUpload) mediaUpload.value = ''; } });
   }
   if (clearMediaBtn) { clearMediaBtn.addEventListener('click', function() { /* ... clear logic ... */ }); }
   function simulateAnalysis(analysisType) { /* ... simulation logic ... */ }
   if (extractTextBtn) extractTextBtn.addEventListener('click', () => simulateAnalysis('ocr'));
   if (analyzeUiBtn) analyzeUiBtn.addEventListener('click', () => simulateAnalysis('ui'));
   if (translateMediaBtn) translateMediaBtn.addEventListener('click', () => simulateAnalysis('translate'));
   if (copyResultsBtn && actualMediaResults) { copyResultsBtn.addEventListener('click', function() { /* ... copy logic ... */ }); }
   if (downloadResultsBtn && actualMediaResults) { downloadResultsBtn.addEventListener('click', function() { /* ... download logic ... */ }); }


  // --- Load Sample Images Functionality ---
  window.loadSampleImage = function(type) {
        let sampleImageUrl = ''; let altText = ''; const placeholderBase = 'https://placehold.co/800x600/1e293b/e2e8f0/';
        switch(type) {
            case 'ris_login': sampleImageUrl = `${placeholderBase}?text=RIS+Login...`; altText = 'RIS Login'; break;
            case 'pacs_config': sampleImageUrl = `${placeholderBase}?text=PACS+Config...`; altText = 'PACS Config'; break;
            case 'worklist_error': sampleImageUrl = `${placeholderBase}?text=Worklist+Error...`; altText = 'Worklist Error'; break;
            case 'dicom_viewer': sampleImageUrl = `${placeholderBase}?text=DICOM+Viewer...`; altText = 'DICOM Viewer'; break;
            default: console.warn('Unknown type:', type); return;
        }
        if (previewImage && previewVideo && previewContainer && dropZoneOverlay && clearMediaBtn) {
             clearMediaBtn.click(); previewImage.src = sampleImageUrl; previewImage.alt = altText; previewImage.style.display = 'block';
             previewVideo.style.display = 'none'; previewVideo.src = '#'; previewContainer.classList.add('has-preview'); dropZoneOverlay.style.display = 'none';
             if (actualMediaResults) actualMediaResults.classList.add('hidden'); if (mediaResultsPlaceholder) mediaResultsPlaceholder.classList.remove('hidden'); if (mediaLoadingIndicator) mediaLoadingIndicator.classList.add('hidden');
        }
    }

  // --- Initial Setup ---
  updateLangLabels();
  updateWordCount(originalText, originalWordCount);
  if(translatedWordCount) translatedWordCount.textContent = '0 words';

}); // End DOMContentLoaded