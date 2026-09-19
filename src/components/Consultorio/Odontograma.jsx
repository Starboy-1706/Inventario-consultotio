import React from 'react'
const sup = ['18','17','16','15','14','13','12','11', '21','22','23','24','25','26','27','28']
const inf = ['48','47','46','45','44','43','42','41', '31','32','33','34','35','36','37','38']

export default function Odontograma({ selected = [], onChange }) {
  const toggle = (num) => {
    if (selected.includes(num)) onChange(selected.filter(d => d !== num))
    else onChange([...selected, num])
  }

  return (
    <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-3">
      <div className="flex justify-between items-center text-xs text-slate-500 font-bold border-b pb-2">
        <span>ODONTOGRAMA (Seleccione Dientes Tratados)</span>
        <span className="text-teal-600 font-mono">{selected.length ? selected.join(', ') : 'Ninguno'}</span>
      </div>
      <div className="space-y-2 text-center">
        <div>
          <p className="text-[10px] text-slate-400 uppercase font-semibold mb-1">Arcada Superior</p>
          <div className="flex flex-wrap justify-center gap-1">
            {sup.map(num => {
              const isSel = selected.includes(num)
              return (
                <button type="button" key={num} onClick={() => toggle(num)}
                  className={`w-7 h-9 rounded-lg text-[10px] font-bold border transition-all flex flex-col items-center justify-between p-1 ${
                    isSel ? 'bg-teal-600 text-white border-teal-700 shadow-md scale-105' : 'bg-white text-slate-700 border-slate-200 hover:border-teal-300'
                  }`}>
                  <span>{num}</span>
                  <div className={`w-3 h-3 rounded-full border ${isSel ? 'bg-white' : 'bg-slate-100'}`} />
                </button>
              )
            })}
          </div>
        </div>
        <div>
          <p className="text-[10px] text-slate-400 uppercase font-semibold mb-1">Arcada Inferior</p>
          <div className="flex flex-wrap justify-center gap-1">
            {inf.map(num => {
              const isSel = selected.includes(num)
              return (
                <button type="button" key={num} onClick={() => toggle(num)}
                  className={`w-7 h-9 rounded-lg text-[10px] font-bold border transition-all flex flex-col items-center justify-between p-1 ${
                    isSel ? 'bg-teal-600 text-white border-teal-700 shadow-md scale-105' : 'bg-white text-slate-700 border-slate-200 hover:border-teal-300'
                  }`}>
                  <div className={`w-3 h-3 rounded-full border ${isSel ? 'bg-white' : 'bg-slate-100'}`} />
                  <span>{num}</span>
                </button>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
