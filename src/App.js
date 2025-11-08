import React, { useState } from 'react';
import { AlertCircle, FileCode, Download, Upload, Github, Play, Loader } from 'lucide-react';
import './App.css';
import statelessorLogo from './statelessor.png';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'https://statelessor-api.port2aws.pro';

const StatefulAnalyzer = () => {
  const [activeTab, setActiveTab] = useState('upload');
  const [analysisResults, setAnalysisResults] = useState(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [gitUrl, setGitUrl] = useState('');
  const [uploadedFile, setUploadedFile] = useState(null);
  const [jsonData, setJsonData] = useState(null);
  const [sshKey, setSshKey] = useState(null);
  const [isGeneratingKey, setIsGeneratingKey] = useState(false);
  const [keyId, setKeyId] = useState(null);
  const [branch, setBranch] = useState('');
  const [subfolder, setSubfolder] = useState('');
  const [expandedCategories, setExpandedCategories] = useState(new Set());
  const [expandedActions, setExpandedActions] = useState(new Set());
  const [isTestingConnection, setIsTestingConnection] = useState(false);
  
  // Check if repository is public based on URL (both HTTPS and SSH)
  const isPublicRepo = gitUrl && gitUrl.includes('github.com');

  const downloadScript = async (os) => {
    try {
      const requestId = crypto.randomUUID();
      const response = await fetch(`${API_BASE_URL}/api/script/${os}`, {
        headers: {
          'X-Request-ID': requestId
        }
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const blob = await response.blob();
      const filename = os === 'bash' ? 'analyze.sh' : 'analyze.ps1';
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download failed:', error);
      alert('Backend API not available. Please ensure the backend server is running on port 3001.');
    }
  };

  const handleFileUpload = (e) => {
    const file = e.target.files[0];
    if (file) {
      if (file.name.endsWith('.zip')) {
        setUploadedFile(file);
        setActiveTab('upload');
      } else if (file.name.endsWith('.json')) {
        const reader = new FileReader();
        reader.onload = (event) => {
          try {
            const json = JSON.parse(event.target.result);
            setJsonData(json);
            setActiveTab('json');
          } catch (err) {
            alert('Invalid JSON file');
          }
        };
        reader.readAsText(file);
      }
    }
  };

  const analyzeCode = async () => {
    setIsAnalyzing(true);
    try {
      const requestId = crypto.randomUUID();
      let response;
      
      if (activeTab === 'upload' && uploadedFile) {
        const formData = new FormData();
        formData.append('zipFile', uploadedFile);
        formData.append('type', 'zip');
        
        response = await fetch(`${API_BASE_URL}/analyze`, {
          method: 'POST',
          headers: {
            'X-Request-ID': requestId
          },
          body: formData
        });
      } else if (activeTab === 'git' && gitUrl) {
        const payload = {
          type: 'git',
          gitUrl: gitUrl,
          branch: branch || undefined,
          subfolder: subfolder || undefined
        };
        
        // Add keyId for SSH URLs when available
        if (gitUrl.startsWith('git@') && keyId) {
          payload.keyId = keyId;
        }
        
        console.log('Sending payload to backend:', payload);
        
        response = await fetch(`${API_BASE_URL}/analyze`, {
          method: 'POST',
          headers: { 
            'X-Request-ID': requestId,
            'Content-Type': 'application/json' 
          },
          body: JSON.stringify(payload)
        });
      } else if (activeTab === 'json' && jsonData) {
        response = await fetch(`${API_BASE_URL}/analyze`, {
          method: 'POST',
          headers: { 
            'X-Request-ID': requestId,
            'Content-Type': 'application/json' 
          },
          body: JSON.stringify({
            type: 'json',
            jsonData: JSON.stringify(jsonData)
          })
        });
      }
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error('HTTP Error:', response.status, errorText);
        alert(`Analysis failed (${response.status}): ${errorText}`);
        setIsAnalyzing(false);
        return;
      }
      
      const results = await response.json();
      console.log('Backend response:', results);
      
      if (results.error) {
        alert('Analysis failed: ' + (results.message || 'Unknown error'));
        setIsAnalyzing(false);
        return;
      } else {
        setAnalysisResults(results);
      }
    } catch (error) {
      console.error('Analysis failed:', error);
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        alert('Cannot connect to backend server. Please check your connection and try again.');
      } else {
        alert('Analysis failed: ' + error.message);
      }
    } finally {
      setIsAnalyzing(false);
    }
    setIsAnalyzing(false);
  };

  const generateSSHKey = async () => {
    setIsGeneratingKey(true);
    try {
      const requestId = crypto.randomUUID();
      const response = await fetch(`${API_BASE_URL}/api/ssh/generate`, {
        method: 'POST',
        headers: { 
          'X-Request-ID': requestId,
          'Content-Type': 'application/json' 
        },
        body: JSON.stringify({})
      });
      const data = await response.json();
      if (data.success) {
        setSshKey(data.publicKey);
        setKeyId(data.keyId);
      } else {
        alert('Failed to generate SSH key: ' + data.error);
      }
    } catch (error) {
      alert('Failed to generate SSH key. Please try again.');
    }
    setIsGeneratingKey(false);
  };

  const copySSHKey = () => {
    navigator.clipboard.writeText(sshKey);
    alert('SSH key copied to clipboard!');
  };

  const toggleCategory = (categoryId) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(categoryId)) {
      newExpanded.delete(categoryId);
    } else {
      newExpanded.add(categoryId);
    }
    setExpandedCategories(newExpanded);
  };

  const toggleActions = (categoryId) => {
    const newExpanded = new Set(expandedActions);
    if (newExpanded.has(categoryId)) {
      newExpanded.delete(categoryId);
    } else {
      newExpanded.add(categoryId);
    }
    setExpandedActions(newExpanded);
  };

  const testConnection = async () => {
    if (!gitUrl) {
      alert('Please enter a repository URL first.');
      return;
    }
    
    setIsTestingConnection(true);
    try {
      const requestId = crypto.randomUUID();
      const payload = {
        gitUrl: gitUrl,
        branch: branch || undefined
      };
      
      // Add keyId for SSH URLs when available
      if (gitUrl.startsWith('git@') && keyId) {
        payload.keyId = keyId;
      }
      
      const response = await fetch(`${API_BASE_URL}/api/git/test-connection`, {
        method: 'POST',
        headers: {
          'X-Request-ID': requestId,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });
      
      const result = await response.json();
      if (result.success) {
        alert('✓ Connection successful! Repository is accessible.');
      } else {
        alert('✗ Connection failed: ' + (result.message || 'Repository not accessible'));
      }
    } catch (error) {
      console.error('Connection test failed:', error);
      alert('✗ Connection test failed. Please check your network and try again.');
    }
    setIsTestingConnection(false);
  };

  const exportResults = () => {
    if (!analysisResults) return;
    const csv = [['Filename', 'Function', 'Line', 'Code', 'Issue Type', 'Severity', 'Remediation'], ...analysisResults.detailed.map(f => [f.filename, f.function, f.lineNum, f.code, f.category, f.severity, f.remediation])].map(row => row.map(cell => `"${cell}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'stateful-analysis-results.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="app">
      <div className="header">
        <div className="header-content">
          <div className="logo-section">
            <div className="logo">
              <img src={statelessorLogo} alt="Statelessor" className="logo-image" />
            </div>
            <div>
              <h1 className="title">Statelessor</h1>
              <p className="subtitle">Identify reasons for Statefulness; Use AI Assisted fix to make Stateless</p>
            </div>
          </div>
          <div className="header-buttons">
            {/* Download buttons moved to JSON tab */}
          </div>
        </div>
      </div>

      <div className="main-content">
        {!analysisResults ? (
          <div className="card">
            <h2>Choose Analysis Method</h2>
            <p className="analysis-description">
              <em>You have 3 options to complete the analysis for statefulness. The 1st method expects Source code to be uploaded in ZIP form, while 2nd Option expects you to share and authorize GitHub repo. The last option is to run the scan manually and upload the scanned output here. 1st option is recommended for small project while last option is recommended for proprietory/confidential assets</em>
            </p>
            
            <div className="tabs">
              {[{id: 'upload', label: 'Upload ZIP', icon: Upload}, {id: 'git', label: 'Git Repository', icon: Github}, {id: 'json', label: 'Upload JSON', icon: FileCode}].map(tab => (
                <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={`tab ${activeTab === tab.id ? 'active' : ''}`}>
                  <tab.icon size={16} />
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="tab-content">
              {activeTab === 'upload' && (
                <div className="upload-tab-container">
                  <div className="upload-left">
                    <div className="instructions">
                      <p>You can upload your source code to get this analysis done. Please ensure to compress this at Project Root folder and upload the Zip file here.</p>
                      <p>If your project is big (spanning multiple folders and files), please follow other 2 process of analysis, instead of this.</p>
                    </div>
                  </div>
                  <div className="upload-right">
                    <div className="upload-area">
                      <Upload size={48} />
                      <label className="upload-label">
                        <span className="upload-title">Upload your source code</span>
                        <p className="upload-desc">ZIP files containing .NET or Java projects</p>
                        <input type="file" className="file-input" accept=".zip" onChange={handleFileUpload} />
                        <span className="btn-primary">Choose File</span>
                      </label>
                      {uploadedFile && <p className="success">✓ {uploadedFile.name}</p>}
                    </div>
                  </div>
                </div>
              )}

              {activeTab === 'git' && (
                <div className="git-tab-container">
                  <div className="git-left">
                    <div className="repo-input-section">
                      <label className="input-label">GitHub Repository URL</label>
                      <input 
                        type="url" 
                        value={gitUrl} 
                        onChange={(e) => setGitUrl(e.target.value)} 
                        placeholder="https://github.com/username/repository" 
                        className="text-input" 
                      />
                      <div className="repo-options">
                        <div className="option-group">
                          <label className="input-label">Branch (optional)</label>
                          <input 
                            type="text" 
                            value={branch}
                            onChange={(e) => setBranch(e.target.value)}
                            placeholder="main" 
                            className="text-input" 
                          />
                        </div>
                        <div className="option-group">
                          <label className="input-label">Subfolder (optional)</label>
                          <input 
                            type="text" 
                            value={subfolder}
                            onChange={(e) => setSubfolder(e.target.value)}
                            placeholder="src/" 
                            className="text-input" 
                          />
                        </div>
                      </div>
                      <button 
                        onClick={testConnection}
                        disabled={isTestingConnection || !gitUrl}
                        className="btn-secondary test-connection-btn"
                      >
                        {isTestingConnection ? <Loader className="spinner" size={16} /> : 'Test Connection'}
                      </button>
                    </div>
                  </div>
                  <div className="git-right">
                    {isPublicRepo ? (
                      <div className="public-repo-info">
                        <h4>✓ Public Repository Access</h4>
                        <div className="instructions">
                          <p>No SSH setup required for public repositories.</p>
                          <p>Simply enter the repository URL and click "Start Analysis".</p>
                          <div className="info-note">
                            <strong>For Private Repositories:</strong>
                            <p>If you need to analyze a private repository, you'll need to generate SSH keys and add them as deploy keys to your repository.</p>
                          </div>
                        </div>
                      </div>
                    ) : (
                      <div className="ssh-setup">
                        <h4>SSH Setup Instructions</h4>
                        <div className="instructions">
                          <ol>
                            <li>Copy the public key below</li>
                            <li>Go to your GitHub repository → Settings → Deploy Keys</li>
                            <li>Click "Add deploy key" and paste the key</li>
                            <li>Give it a title like "Statelessor Analysis"</li>
                            <li>Leave "Allow write access" unchecked</li>
                            <li>Click "Add key"</li>
                          </ol>
                        </div>
                        <div className="ssh-key-section">
                          {!sshKey ? (
                            <button 
                              onClick={generateSSHKey} 
                              disabled={isGeneratingKey}
                              className="btn-primary generate-key-btn"
                            >
                              {isGeneratingKey ? <Loader className="spinner" size={16} /> : 'Generate SSH Key'}
                            </button>
                          ) : (
                            <>
                              <label className="input-label">Public SSH Key</label>
                              <textarea 
                                className="ssh-key-display" 
                                readOnly 
                                value={sshKey}
                                rows={3}
                              />
                              <div className="key-actions">
                                <button onClick={copySSHKey} className="btn-secondary copy-key-btn">
                                  Copy Key
                                </button>
                                <button onClick={() => setSshKey(null)} className="btn-secondary">
                                  Generate New Key
                                </button>
                              </div>
                            </>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {activeTab === 'json' && (
                <div className="json-tab-container">
                  <div className="json-left">
                    <div className="instructions">
                      <p>In case, you want to analyze locally, download the script and keep this into project root. Run the script, which will generate a JSON output. Once you have JSON, you can return to this screen to upload the same.</p>
                    </div>
                    <div className="download-buttons">
                      <button onClick={() => downloadScript('bash')} className="btn-primary">
                        <Download size={16} />
                        Bash Script
                      </button>
                      <button onClick={() => downloadScript('powershell')} className="btn-primary">
                        <Download size={16} />
                        PowerShell Script
                      </button>
                    </div>
                  </div>
                  <div className="json-right">
                    <div className="upload-area">
                      <FileCode size={48} />
                      <label className="upload-label">
                        <span className="upload-title">Upload analysis JSON</span>
                        <p className="upload-desc">JSON file generated by the analysis script</p>
                        <input type="file" className="file-input" accept=".json" onChange={handleFileUpload} />
                        <span className="btn-primary">Choose JSON File</span>
                      </label>
                      {jsonData && <p className="success">✓ JSON file loaded</p>}
                    </div>
                  </div>
                </div>
              )}

              <div className="analyze-section">
                <button onClick={analyzeCode} disabled={isAnalyzing || (!uploadedFile && !gitUrl && !jsonData)} className="btn-analyze">
                  {isAnalyzing ? <Loader className="spinner" size={20} /> : <Play size={20} />}
                  {isAnalyzing ? 'Analyzing...' : 'Start Analysis'}
                </button>
              </div>
            </div>
          </div>
        ) : (
          <div className="results">
            <div className="project-header">
              <h2>{analysisResults.projectName}</h2>
              <p className="project-meta">
                {analysisResults.projectType.toUpperCase()} • Scanned on {new Date(analysisResults.scanDate).toLocaleDateString()}
                {analysisResults.complexityFactor > 1 && <span className="complexity"> • Complexity Factor: {analysisResults.complexityFactor}x</span>}
              </p>
            </div>

            <div className="stats-grid">
              {[
                {label: 'Total Files', value: analysisResults.stats.totalFiles, color: 'blue'},
                {label: 'Total Issues', value: analysisResults.stats.totalIssues, color: 'red'},
                {label: 'High Severity', value: analysisResults.stats.highSeverity, color: 'red'},
                {label: 'Medium Severity', value: analysisResults.stats.mediumSeverity, color: 'yellow'},
                {label: 'Low Severity', value: analysisResults.stats.lowSeverity, color: 'blue'},
                {label: 'Effort Score', value: Math.round(analysisResults.stats.totalEffortScore), color: 'purple'}
              ].map((stat, idx) => (
                <div key={idx} className="stat-card">
                  <div className="stat-content">
                    <div className={`stat-icon ${stat.color}`}>
                      <AlertCircle size={20} />
                    </div>
                    <div>
                      <p className="stat-label">{stat.label}</p>
                      <p className="stat-value">{stat.value}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="results-tree-container">
              <div className="results-header">
                <h3>Analysis Results</h3>
                <button onClick={exportResults} className="btn-secondary">
                  <Download size={16} />
                  Export CSV
                </button>
              </div>
              <div className="tree-view">
                {analysisResults.summary.map((category) => (
                  <div key={category.id} className="tree-category">
                    <div 
                      className="category-header" 
                      onClick={() => toggleCategory(category.id)}
                    >
                      <span className={`expand-icon ${expandedCategories.has(category.id) ? 'expanded' : ''}`}>▶</span>
                      <span className={`severity-badge ${category.severity}`}>{category.severity}</span>
                      <span className="category-name">{category.category}</span>
                      <span className="occurrence-count">({category.occurrences} occurrences)</span>
                      <span className="effort-score">Effort: {Math.round(category.effortScore)}</span>
                    </div>
                    
                    {expandedCategories.has(category.id) && (
                      <div className="category-details">
                        <div className="remediation-box">
                          <strong>Recommended Solution:</strong>
                          <p>{category.remediation}</p>
                        </div>
                        
                        <div className="findings-list">
                          {analysisResults.detailed
                            .filter(detail => category.detailIds.includes(detail.id))
                            .map((finding) => (
                              <div key={finding.id} className="finding-item">
                                <div className="finding-header">
                                  <span className="filename">{finding.filename}</span>
                                  <span className="function-name">
                                    {finding.function === 'Unknown' ? 'Class Level' : finding.function}
                                  </span>
                                  <span className="line-number">Line {finding.lineNum}</span>
                                </div>
                                <div className="code-snippet">{finding.code}</div>
                              </div>
                            ))
                          }
                        </div>

                        <div className="actions-section">
                          <div 
                            className="actions-header"
                            onClick={() => toggleActions(category.id)}
                          >
                            <span className={`expand-icon ${expandedActions.has(category.id) ? 'expanded' : ''}`}>▶</span>
                            <span className="actions-title">Implementation Roadmap</span>
                          </div>
                          
                          {expandedActions.has(category.id) && analysisResults.actions && (
                            <div className="actions-list">
                              {analysisResults.actions
                                .filter(action => {
                                  return action.affectedFindings.some(af => 
                                    analysisResults.detailed
                                      .filter(d => category.detailIds.includes(d.id))
                                      .some(d => d.filename === af.filename && d.lineNum === af.lineNum)
                                  );
                                })
                                .map((action) => (
                                  <div key={action.id} className="action-item">
                                    <div className="action-header">
                                      <span className="action-category">{action.category}</span>
                                      <span className="action-effort">Effort: {action.finalEffort}</span>
                                    </div>
                                    <div className="action-description">{action.description}</div>
                                    {action.subActions && (
                                      <div className="sub-actions">
                                        {action.subActions.map((subAction, idx) => (
                                          <div key={idx} className="sub-action">• {subAction}</div>
                                        ))}
                                      </div>
                                    )}
                                  </div>
                                ))
                              }
                            </div>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            <div className="new-analysis">
              <button onClick={() => setAnalysisResults(null)} className="btn-secondary">
                New Analysis
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default StatefulAnalyzer;