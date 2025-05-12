// public/js/script.js

// Client-side configuration (API keys, etc., are now server-side)
const APP_CONFIG = { // Renamed from API_CONFIG to avoid confusion
    userId: 'user-' + Math.random().toString(36).substring(2, 15),
    difyResponseMode: 'streaming'
};

// Local endpoint for file uploads to your Sinatra server
const LOCAL_UPLOAD_URL = '/upload-local-file'; // Matches Sinatra route
// Local proxy endpoint in your Sinatra app that calls DifyClient
const MEMEXRAG_DIFY_PROXY_URL = '/memexrag/proxy/dify_workflow'; // Matches Sinatra route

document.addEventListener('DOMContentLoaded', function() {
    // ... (tab switching, file dropzone, and other UI setup remains largely the same) ...
    // Ensure all getElementById calls are checked for null or done after DOM is ready.

    const tabs = document.querySelectorAll('.input-tab');
    const inputContents = document.querySelectorAll('.input-content');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            const tabName = tab.getAttribute('data-tab');
            inputContents.forEach(content => {
                content.classList.add('hidden');
                if (content.id === `${tabName}-input`) {
                    content.classList.remove('hidden');
                }
            });
        });
    });

    const fileDropzone = document.getElementById('file-dropzone');
    const fileInput = document.getElementById('file-upload');
    const fileInfo = document.getElementById('file-info');
    const fileNameDisplay = document.getElementById('file-name');
    const removeFileBtn = document.getElementById('remove-file');
    const fileUploadProgress = document.getElementById('file-upload-progress');
    const fileUploadBar = document.getElementById('file-upload-bar');
    const fileUploadPercent = document.getElementById('file-upload-percent');

    if (fileDropzone) {
        ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => fileDropzone.addEventListener(eventName, preventDefaults, false));
        ['dragenter', 'dragover'].forEach(eventName => fileDropzone.addEventListener(eventName, highlight, false));
        ['dragleave', 'drop'].forEach(eventName => fileDropzone.addEventListener(eventName, unhighlight, false));
        fileDropzone.addEventListener('drop', handleDrop, false);
    }

    function preventDefaults(e) { e.preventDefault(); e.stopPropagation(); }
    function highlight() { if (fileDropzone) fileDropzone.classList.add('drag-active'); }
    function unhighlight() { if (fileDropzone) fileDropzone.classList.remove('drag-active'); }

    function handleDrop(e) {
        const files = e.dataTransfer.files;
        if (files.length && fileInput) { fileInput.files = files; handleFiles(files); }
    }

    if (fileInput) {
        fileInput.addEventListener('change', function() { if (this.files.length) handleFiles(this.files); });
    }

    function handleFiles(files) {
        const file = files[0];
        if (fileNameDisplay && fileInfo) {
            fileNameDisplay.textContent = file.name;
            fileInfo.classList.remove('hidden');
            if (fileUploadBar) fileUploadBar.style.width = '0%';
            if (fileUploadPercent) fileUploadPercent.textContent = '0%';
            if (fileUploadProgress) fileUploadProgress.classList.add('hidden');
        }
    }

    if (removeFileBtn) {
        removeFileBtn.addEventListener('click', function() {
            if (fileInput) fileInput.value = '';
            if (fileInfo) fileInfo.classList.add('hidden');
            if (fileUploadBar) fileUploadBar.style.width = '0%';
            if (fileUploadPercent) fileUploadPercent.textContent = '0%';
            if (fileUploadProgress) fileUploadProgress.classList.add('hidden');
        });
    }


    const translateBtn = document.getElementById('translate-btn');
    if (translateBtn) {
        translateBtn.addEventListener('click', async () => {
            const activeTabEl = document.querySelector('.input-tab.active');
            if (!activeTabEl) { addStatusMessage('Error: Could not determine input type.', 'error'); return; }
            const activeTab = activeTabEl.getAttribute('data-tab');
            const sourceTextEl = document.getElementById('source-text');
            const sourceUrlEl = document.getElementById('source-url');
            let inputsForDifyWorkflow = {}; // This will be sent to your Sinatra proxy

            const statusSection = document.getElementById('status-section');
            const resultsSection = document.getElementById('results-section');
            const currentApiStatus = document.getElementById('api-status');
            const currentStatusMessages = document.getElementById('status-messages');

            if (activeTab === 'text') {
                if (!sourceTextEl) { addStatusMessage('Error: Text input area not found.', 'error'); return; }
                const textContent = sourceTextEl.value.trim();
                if (!textContent) { addStatusMessage('Please enter text to translate.', 'error'); return; }
                inputsForDifyWorkflow = { text: textContent }; // Dify input variable name
            } else if (activeTab === 'file') {
                if (!fileInput || !fileInput.files.length) { addStatusMessage('Please upload a file.', 'error'); return; }
                const fileToUpload = fileInput.files[0];
                try {
                    addStatusMessage(`Uploading ${fileToUpload.name} to local server...`, 'info');
                    const localUploadResponse = await uploadFileToLocalServer(fileToUpload); // Uploads to Sinatra
                    addStatusMessage(`${localUploadResponse.id} uploaded locally. Preparing for Dify workflow.`, 'info');

                    // Now, structure the input for Dify based on how your Dify workflow expects files.
                    // Option A: Dify workflow expects text content from file
                    // inputsForDifyWorkflow = { text_from_file: await fileToUpload.text(), original_filename: localUploadResponse.id };

                    // Option B: Dify workflow expects a Dify 'upload_file_id'.
                    //    Your Sinatra proxy would need to take `localUploadResponse.id` (local filename),
                    //    read the file from `public/uploads`, upload it to Dify's /files/upload endpoint,
                    //    get Dify's file ID, and then use that in the call to Dify workflow. This is complex for the proxy.

                    // Option C: Dify workflow expects a public URL to the file.
                    // inputsForDifyWorkflow = { file_url: window.location.origin + localUploadResponse.public_url };

                    // Option D: Simplest if Dify workflow has an input variable (e.g., 'document_content')
                    // that can take the text content of the file.
                    const fileContent = await fileToUpload.text();
                    inputsForDifyWorkflow = {
                        // This key 'document_text' MUST match an input variable in your Dify workflow
                        document_text: fileContent,
                        original_filename: localUploadResponse.id // Optional: send filename too
                    };
                    addStatusMessage(`File content prepared. Sending to Dify workflow...`, 'info');

                } catch (uploadError) {
                    addStatusMessage(`File handling error: ${uploadError.message}`, 'error');
                    if (currentApiStatus) currentApiStatus.classList.add('hidden');
                    return;
                }
            } else if (activeTab === 'url') {
                if (!sourceUrlEl) { addStatusMessage('Error: URL input area not found.', 'error'); return; }
                const urlContent = sourceUrlEl.value.trim();
                if (!urlContent) { addStatusMessage('Please enter a valid URL.', 'error'); return; }
                if (!isValidUrl(urlContent)) { addStatusMessage('Please enter a valid URL (http:// or https://).', 'error'); return; }
                inputsForDifyWorkflow = { url_input: urlContent }; // Dify input variable name
            }

            if (statusSection) statusSection.classList.remove('hidden');
            if (resultsSection) resultsSection.classList.add('hidden');
            if (currentStatusMessages) currentStatusMessages.innerHTML = '';
            if (currentApiStatus) currentApiStatus.classList.remove('hidden');

            try {
                await executeDifyWorkflowViaMemexRAGProxy(inputsForDifyWorkflow);
            } catch (error) {
                console.error('Workflow execution error:', error);
                addStatusMessage(`Workflow error: ${error.message || 'Failed to process translation'}`, 'error');
            } finally {
                if (currentApiStatus) currentApiStatus.classList.add('hidden');
            }
        });
    }

    // Uploads file to your local Sinatra server endpoint
    async function uploadFileToLocalServer(file) {
        const currentFileUploadBar = document.getElementById('file-upload-bar');
        const currentFileUploadPercent = document.getElementById('file-upload-percent');
        const currentFileUploadProgress = document.getElementById('file-upload-progress');
        if(currentFileUploadProgress) currentFileUploadProgress.classList.remove('hidden');

        return new Promise((resolve, reject) => {
            const formData = new FormData();
            formData.append('file', file); // Key 'file' must match Sinatra's params[:file]
            const xhr = new XMLHttpRequest();
            xhr.open('POST', LOCAL_UPLOAD_URL, true);
            xhr.upload.onprogress = function(e) {
                if (e.lengthComputable) {
                    const percentComplete = (e.loaded / e.total) * 100;
                    if (currentFileUploadBar) currentFileUploadBar.style.width = percentComplete + '%';
                    if (currentFileUploadPercent) currentFileUploadPercent.textContent = Math.round(percentComplete) + '%';
                }
            };
            xhr.onload = function() {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        if (response.status === 'success' && response.id) resolve(response);
                        else reject(new Error(response.message || 'Local file upload failed to return valid ID.'));
                    } catch (e) { reject(new Error('Invalid JSON response from local upload server.')); }
                } else { reject(new Error(`Local upload to ${LOCAL_UPLOAD_URL} failed: ${xhr.status} ${xhr.statusText}`)); }
            };
            xhr.onerror = function() { reject(new Error('Local upload network error.')); };
            xhr.send(formData);
        });
    }


    async function executeDifyWorkflowViaMemexRAGProxy(difyInputs) {
        const progressFill = document.getElementById('progress-fill');
        const aiRefinedTamilEl = document.getElementById('ai-refined-tamil');

        addStatusMessage('Connecting to Dify via MemexRAG proxy...', 'info');
        updateProgress(0, progressFill);
        if (aiRefinedTamilEl) aiRefinedTamilEl.textContent = ''; // Clear previous streaming text

        try {
            const response = await fetch(MEMEXRAG_DIFY_PROXY_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream'
                },
                body: JSON.stringify({
                    inputs: difyInputs,
                    user: APP_CONFIG.userId,
                    response_mode: APP_CONFIG.difyResponseMode
                })
            });

            if (!response.ok) {
                let errorData = { message: `Proxy request to ${MEMEXRAG_DIFY_PROXY_URL} failed: ${response.status} ${response.statusText}`};
                try { errorData = await response.json(); } catch(e) { /* ignore */ }
                throw new Error(errorData.message || `Proxy request failed: ${response.status}`);
            }
            if (!response.body) throw new Error("Response body is null from proxy.");

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';
            // eslint-disable-next-line no-constant-condition
            while (true) {
                const { value, done } = await reader.read();
                if (done) {
                    // Check if workflow_finished event was processed. If not, assume completion.
                    const currentStatusMessages = document.getElementById('status-messages');
                    let alreadyFinished = false;
                    if (currentStatusMessages) {
                        for (let i = 0; i < currentStatusMessages.children.length; i++) {
                            if (currentStatusMessages.children[i].textContent.includes("Workflow completed successfully")) {
                                alreadyFinished = true;
                                break;
                            }
                        }
                    }
                    if (!alreadyFinished) addStatusMessage('Translation stream ended.', 'info');
                    break;
                }
                buffer += decoder.decode(value, { stream: true });
                let EOL;
                while ((EOL = buffer.indexOf('\n\n')) >= 0) {
                    const eventString = buffer.substring(0, EOL);
                    buffer = buffer.substring(EOL + 2);
                    let eventName = 'message', eventData = '';
                    eventString.split('\n').forEach(line => {
                        if (line.startsWith('event:')) eventName = line.substring('event:'.length).trim();
                        else if (line.startsWith('data:')) eventData = line.substring('data:'.length).trim();
                    });

                    if (eventData) {
                        try {
                            const jsonData = JSON.parse(eventData);
                            // console.log("SSE Event from Proxy:", eventName, jsonData);
                            if (eventName === 'error' || (jsonData.event && jsonData.event === 'error')) { // Handle error event from proxy
                                addStatusMessage(`Error from Dify service: ${jsonData.message || jsonData.error || 'Unknown error'}`, 'error');
                                updateProgress(100, progressFill);
                                throw new Error(jsonData.message || 'Dify workflow error via proxy');
                            }

                            if (jsonData.event === 'workflow_started') {
                                addStatusMessage('Workflow started (via proxy): ' + (jsonData.task_id || ''), 'info');
                                updateProgress(10, progressFill);
                            } else if (jsonData.event === 'node_started') {
                                addStatusMessage(`Processing: ${(jsonData.data && jsonData.data.title) || 'step'}`, 'info');
                                const currentProgress = parseFloat(progressFill.style.width) || 0;
                                updateProgress(Math.min(90, currentProgress + 10), progressFill); // Smaller increments
                            } else if (jsonData.event === 'node_finished') {
                                if (jsonData.data && jsonData.data.status === 'succeeded') {
                                    addStatusMessage(`Completed: ${(jsonData.data.title) || 'step'}`, 'success');
                                } else {
                                    addStatusMessage(`Node Failed: ${(jsonData.data && jsonData.data.title)} - ${(jsonData.data && jsonData.data.error) || 'node error'}`, 'error');
                                }
                            } else if (jsonData.event === 'llm_chunk') {
                                if (aiRefinedTamilEl && jsonData.data && jsonData.data.answer) {
                                   aiRefinedTamilEl.textContent += jsonData.data.answer;
                                }
                            } else if (jsonData.event === 'workflow_finished') {
                                if (jsonData.data && jsonData.data.status === 'succeeded') {
                                    addStatusMessage('Workflow completed successfully!', 'success');
                                    updateProgress(100, progressFill);
                                    processWorkflowOutputs(jsonData.data.outputs);
                                    const statusSect = document.getElementById('status-section');
                                    const resultsSect = document.getElementById('results-section');
                                    if(statusSect) statusSect.classList.add('hidden');
                                    if(resultsSect) { resultsSect.classList.remove('hidden'); resultsSect.scrollIntoView({ behavior: 'smooth' });}
                                } else {
                                    addStatusMessage(`Workflow failed (via proxy): ${(jsonData.data && jsonData.data.error) || 'Unknown error'}`, 'error');
                                    updateProgress(100, progressFill);
                                }
                                return; // Exit processing loop
                            }
                        } catch (e) { console.error('Error parsing SSE JSON from proxy or processing event:', e, "Raw data:", eventData); }
                    }
                }
            }
        } catch (error) {
            console.error('Fetch/SSE to proxy error:', error);
            addStatusMessage(`Connection to MemexRAG proxy failed: ${error.message}`, 'error');
            updateProgress(100, progressFill);
            throw error;
        }
    }

    // ... (processWorkflowOutputs, addStatusMessage, updateProgress, isValidUrl, copy button logic remain similar)
    // Ensure these helper functions are robust.
    function processWorkflowOutputs(outputs) {
        const originalTextEl = document.getElementById('original-text');
        const aiRefinedTamilEl = document.getElementById('ai-refined-tamil');
        const standardTamilEl = document.getElementById('standard-tamil');
        const roundtripEnglishEl = document.getElementById('roundtrip-english');

        const originalText = outputs?.original_text || (outputs?.input_text) || "Original text not provided by workflow.";
        // If aiRefinedTamilEl was streamed, its content is already there.
        // Only set it if not streamed or if outputs provide a final complete version.
        if (aiRefinedTamilEl && (!aiRefinedTamilEl.textContent || (outputs?.ai_refined_tamil && aiRefinedTamilEl.textContent !== outputs.ai_refined_tamil))) {
            aiRefinedTamilEl.textContent = outputs?.ai_refined_tamil || (outputs?.translated_text) || "AI Tamil translation not provided.";
        } else if (!aiRefinedTamilEl) {
             console.warn("Element 'ai-refined-tamil' not found for output processing.");
        }
        if (standardTamilEl) standardTamilEl.textContent = outputs?.standard_tamil || (outputs?.standard_translation) || "Standard Tamil translation not provided.";
        if (roundtripEnglishEl) roundtripEnglishEl.textContent = outputs?.roundtrip_english || (outputs?.verified_text) || "Roundtrip verification not provided.";
        if (originalTextEl) originalTextEl.textContent = originalText;
    }

    function addStatusMessage(message, type = 'info') {
        const currentStatusMessages = document.getElementById('status-messages');
        if (!currentStatusMessages) {
            console.warn("Status messages element not found. Message:", message);
            if(type === 'error') window.alert(`ERROR: ${message}`); // Fallback for critical errors
            return;
        }
        const messageDiv = document.createElement('div');
        messageDiv.className = 'flex items-center text-sm p-2 my-1 rounded-md shadow';
        let iconClass = 'fas fa-info-circle', textColor = 'text-blue-700', bgColor = 'bg-blue-100';
        if (type === 'success') { iconClass = 'fas fa-check-circle'; textColor = 'text-green-700'; bgColor = 'bg-green-100'; }
        if (type === 'error') { iconClass = 'fas fa-exclamation-circle'; textColor = 'text-red-700'; bgColor = 'bg-red-100'; }
        messageDiv.classList.add(bgColor, textColor);
        messageDiv.innerHTML = `<i class="${iconClass} ${textColor} mr-3 fa-fw"></i><span>${message}</span>`;
        currentStatusMessages.appendChild(messageDiv);
        currentStatusMessages.scrollTop = currentStatusMessages.scrollHeight;
    }

    function updateProgress(percent, progressFillElement) {
        const targetElement = progressFillElement || document.getElementById('progress-fill');
        if (targetElement) targetElement.style.width = `${Math.min(100, Math.max(0, percent))}%`;
    }

    function isValidUrl(string) { try { new URL(string); return true; } catch (_) { return false; } }

    document.addEventListener('click', (e) => {
        const copyButton = e.target.closest('.copy-btn');
        if (copyButton) {
            const targetId = copyButton.getAttribute('data-target');
            const textElement = document.getElementById(targetId);
            if (textElement) {
                const textToCopy = textElement.textContent;
                navigator.clipboard.writeText(textToCopy).then(() => {
                    const originalHTML = copyButton.innerHTML;
                    copyButton.innerHTML = '<i class="fas fa-check mr-1"></i> Copied!';
                    copyButton.classList.add('copied');
                    setTimeout(() => {
                        copyButton.innerHTML = originalHTML;
                        copyButton.classList.remove('copied');
                    }, 2000);
                }).catch(err => { console.error('Failed to copy: ', err); addStatusMessage('Failed to copy.', 'error'); });
            } else { addStatusMessage(`Copy target '${targetId}' not found.`, 'error'); }
        }
    });

});
