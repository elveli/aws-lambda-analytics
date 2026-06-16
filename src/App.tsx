/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import readmeContent from '../README.md?raw';

export default function App() {
  return (
    <div className="min-h-screen bg-[#020617] text-slate-300 font-sans p-8 md:p-16">
      <div className="max-w-4xl mx-auto flex flex-col">
        <header className="mb-8 border-b border-slate-800 pb-6">
          <div className="flex items-center space-x-3 mb-2">
            <div className="w-8 h-8 bg-sky-500 rounded-lg flex items-center justify-center shrink-0">
              <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
            </div>
            <h1 className="text-2xl font-bold tracking-tight text-white">AWS Lambda Showcase</h1>
          </div>
          <p className="text-sm font-medium text-slate-400 mt-4 leading-relaxed bg-slate-900/50 p-4 rounded-xl border border-slate-800/80">
            The requested infrastructure-as-code and backend files have been generated. 
            You can explore the <code className="bg-slate-800/80 px-1.5 py-0.5 border border-slate-700/50 rounded text-xs font-mono text-sky-400">terraform</code> and <code className="bg-slate-800/80 px-1.5 py-0.5 border border-slate-700/50 rounded text-xs font-mono text-sky-400">lambda</code> directories in the file tree.
          </p>
        </header>

        <main className="prose max-w-none flex-1 mt-4">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>
            {readmeContent}
          </ReactMarkdown>
        </main>
      </div>
    </div>
  );
}
