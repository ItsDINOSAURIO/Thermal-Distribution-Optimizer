function varargout = Delgado_Hernandez_P2_1(varargin)
% DELGADO_HERNANDEZ_P2_1 MATLAB code for Delgado_Hernandez_P2_1.fig
%      DELGADO_HERNANDEZ_P2_1, by itself, creates a new DELGADO_HERNANDEZ_P2_1 or raises the existing
%      singleton*.
%
%      H = DELGADO_HERNANDEZ_P2_1 returns the handle to a new DELGADO_HERNANDEZ_P2_1 or the handle to
%      the existing singleton*.
%
%      DELGADO_HERNANDEZ_P2_1('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DELGADO_HERNANDEZ_P2_1.M with the given input arguments.
%
%      DELGADO_HERNANDEZ_P2_1('Property','Value',...) creates a new DELGADO_HERNANDEZ_P2_1 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Delgado_Hernandez_P2_1_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Delgado_Hernandez_P2_1_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Delgado_Hernandez_P2_1

% Last Modified by GUIDE v2.5 04-Apr-2023 21:11:09

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Delgado_Hernandez_P2_1_OpeningFcn, ...
                   'gui_OutputFcn',  @Delgado_Hernandez_P2_1_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Delgado_Hernandez_P2_1 is made visible.
function Delgado_Hernandez_P2_1_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Delgado_Hernandez_P2_1 (see VARARGIN)

% Choose default command line output for Delgado_Hernandez_P2_1
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Delgado_Hernandez_P2_1 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Delgado_Hernandez_P2_1_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in PM1.
function PM1_Callback(hObject, eventdata, handles)
v=get(hObject,'Value');
switch v
    case 1
        set(handles.T2,'String','Calculadora');
        %Ubica Caso1
        set(handles.B1,'Visible','on');
        set(handles.T1,'Visible','on');
        set(handles.E1,'Visible','on');
        %Resetea caso1
        set(handles.T1,'String','1');
        set(handles.E1,'String','Escribe una Operación');
        %Quita caso2
        set(handles.E2,'Visible','off');
        set(handles.B2,'Visible','off');
        set(handles.B3,'Visible','off');
        set(handles.B4,'Visible','off');
        set(handles.A1,'Visible','off');
        set(handles.S1,'Visible','off');
        set(handles.S2,'Visible','off');
        set(handles.T3,'Visible','off');
        set(handles.T4,'Visible','off');
        %Quita caso3
        set(handles.B5,'Visible','off');
        set(handles.B6,'Visible','off');
        set(handles.B7,'Visible','off');
        set(handles.E3,'Visible','off');
        set(handles.E4,'Visible','off');
        set(handles.LB1,'Visible','off');
        %Quita caso4
        set(handles.PM2,'Visible','off');
        set(handles.B8,'Visible','off');
        set(handles.E7,'Visible','off');
        set(handles.E8,'Visible','off');
        set(handles.E9,'Visible','off');
        set(handles.E10,'Visible','off');
        set(handles.E11,'Visible','off');
        set(handles.E12,'Visible','off');
        set(handles.T5,'Visible','off');
        set(handles.T6,'Visible','off');
    case 2 
        set(handles.T2,'String','Graficadora');
        %Quita caso1
        set(handles.B1,'Visible','off');
        set(handles.T1,'Visible','off');
        set(handles.E1,'Visible','off');
        %Quita caso3
        set(handles.B5,'Visible','off');
        set(handles.B6,'Visible','off');
        set(handles.B7,'Visible','off');
        set(handles.E3,'Visible','off');
        set(handles.E4,'Visible','off');
        set(handles.LB1,'Visible','off');
        %Quita caso4
        set(handles.PM2,'Visible','off');
        set(handles.B8,'Visible','off');
        set(handles.E7,'Visible','off');
        set(handles.E8,'Visible','off');
        set(handles.E9,'Visible','off');
        set(handles.E10,'Visible','off');
        set(handles.E11,'Visible','off');
        set(handles.E12,'Visible','off');
        set(handles.T5,'Visible','off');
        set(handles.T6,'Visible','off');
        %Ubica caso2
        set(handles.E2,'Visible','on');
        set(handles.B2,'Visible','on');
        set(handles.B3,'Visible','on');
        set(handles.B4,'Visible','on');
        set(handles.A1,'Visible','on');
        set(handles.S1,'Visible','on');
        set(handles.S2,'Visible','on');
        set(handles.T3,'Visible','on');
        set(handles.T4,'Visible','on');
        %Resetea caso2
        set(handles.E2,'String','Función(x,y)');
        set(handles.B3,'String','Derivada en X');
        set(handles.B4,'String','Derivada en Y');
%         set(handles.A1,'Value',0);
% %         clf(handles.A1,'reset')
        set(handles.S1,'Value',0);
        set(handles.S2,'Value',0);
        set(handles.T3,'String','0');
        set(handles.T4,'String','0');
    case 3 
        set(handles.T2,'String','Ecuaciones Simultáneas');
        %Quita caso1
        set(handles.B1,'Visible','off');
        set(handles.T1,'Visible','off');
        set(handles.E1,'Visible','off');
        %Quita caso2
        set(handles.E2,'Visible','off');
        set(handles.B2,'Visible','off');
        set(handles.B3,'Visible','off');
        set(handles.B4,'Visible','off');
        set(handles.A1,'Visible','off');
        set(handles.S1,'Visible','off');
        set(handles.S2,'Visible','off');
        set(handles.T3,'Visible','off');
        set(handles.T4,'Visible','off');
        %Quita caso4
        set(handles.PM2,'Visible','off');
        set(handles.B8,'Visible','off');
        set(handles.E7,'Visible','off');
        set(handles.E8,'Visible','off');
        set(handles.E9,'Visible','off');
        set(handles.E10,'Visible','off');
        set(handles.E11,'Visible','off');
        set(handles.E12,'Visible','off');
        set(handles.T5,'Visible','off');
        set(handles.T6,'Visible','off');
        %Ubico caso3
        set(handles.B5,'Visible','on');
        set(handles.B6,'Visible','on');
        set(handles.B7,'Visible','on');
        set(handles.E3,'Visible','on');
        set(handles.E4,'Visible','on');
        set(handles.LB1,'Visible','on');
        %Resetea caso3
        set(handles.E3,'String','Escriba la primer ecuación');
        set(handles.E4,'String','Escriba la segunda ecuación');
        set(handles.E5,'String','Escriba la tercera ecuación');
        set(handles.E6,'String','Escriba la cuarta ecuación');
        set(handles.LB1,'String','Soluciones: ');
    case 4 
        set(handles.T2,'String','Ecuaciones Diferenciales');
        %Quita caso1
        set(handles.B1,'Visible','off');
        set(handles.T1,'Visible','off');
        set(handles.E1,'Visible','off');
        %Quita caso2
        set(handles.E2,'Visible','off');
        set(handles.B2,'Visible','off');
        set(handles.B3,'Visible','off');
        set(handles.B4,'Visible','off');
        set(handles.A1,'Visible','off');
        set(handles.S1,'Visible','off');
        set(handles.S2,'Visible','off');
        set(handles.T3,'Visible','off');
        set(handles.T4,'Visible','off');
        %Quita caso3
        set(handles.B5,'Visible','off');
        set(handles.B6,'Visible','off');
        set(handles.B7,'Visible','off');
        set(handles.E3,'Visible','off');
        set(handles.E4,'Visible','off');
        set(handles.LB1,'Visible','off');
        %Ubica caso4
        set(handles.PM2,'Visible','on');
        set(handles.B8,'Visible','on');
        set(handles.E7,'Visible','on');
        set(handles.E8,'Visible','on');
        set(handles.E9,'Visible','on');
        set(handles.E12,'Visible','on');
        set(handles.T5,'Visible','on');
        set(handles.T6,'Visible','on');
        %Resetea caso4
        set(handles.PM2,'Value',1);
        set(handles.E7,'String','a');
        set(handles.E8,'String','b');
        set(handles.E9,'String','c');
        set(handles.E10,'String','d');
        set(handles.E11,'String','e');
        set(handles.E12,'String','y(t)');
        set(handles.T5,'String','Ecuación');
        set(handles.T6,'String','Resultado');

end
% hObject    handle to PM1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns PM1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from PM1


% --- Executes during object creation, after setting all properties.
function PM1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PM1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E1_Callback(hObject, eventdata, handles)
% hObject    handle to E1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E1 as text
%        str2double(get(hObject,'String')) returns contents of E1 as a double


% --- Executes during object creation, after setting all properties.
function E1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in B1.
function B1_Callback(hObject, eventdata, handles)
Op=get(handles.E1,'String');
r=eval(Op);
set(handles.T1,'String',r);
% hObject    handle to B1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function E2_Callback(hObject, eventdata, handles)
% hObject    handle to E2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E2 as text
%        str2double(get(hObject,'String')) returns contents of E2 as a double


% --- Executes during object creation, after setting all properties.
function E2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in B3.
function B3_Callback(hObject, eventdata, handles)
syms x y;
f=get(handles.E2,'String');
dx=diff(eval(f),x);
set(hObject,'String',string(dx))
% hObject    handle to B3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in B4.
function B4_Callback(hObject, eventdata, handles)
syms x y;
f=get(handles.E2,'String');
dy=diff(eval(f),y);
set(hObject,'String',string(dy))
% hObject    handle to B4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in B2.
function B2_Callback(hObject, eventdata, handles)
syms x y z;
xmin=-get(handles.S1,'Value');
xmax=get(handles.S1,'Value');
ymin=-get(handles.S2,'Value');
ymax=get(handles.S2,'Value');
axis(handles.A1, [xmin xmax ymin ymax])
f=get(handles.E2,'String');
[x,y]=meshgrid(xmin:0.1:ymax);
z=eval(f);
surf(handles.A1,x,y,z)
xlabel('x')
ylabel('y')
zlabel('z')
% hObject    handle to B2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on slider movement.
function S1_Callback(hObject, eventdata, handles)
v=get(hObject,'Value');
set(handles.T3,'String',v)
% hObject    handle to S1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function S1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to S1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function S2_Callback(hObject, eventdata, handles)
v=get(hObject,'Value');
set(handles.T4,'String',v)
% hObject    handle to S2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function S2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to S2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in B6.
function B6_Callback(hObject, eventdata, handles)
if get(handles.E6,'Visible')==1
    set(handles.E6,'Visible','off')
elseif get(handles.E5,'Visible')==1
    set(handles.E5,'Visible','off')
end
% hObject    handle to B6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in B5.
function B5_Callback(hObject, eventdata, handles)
if get(handles.E5,'Visible')==0
    set(handles.E5,'Visible','on')
elseif get(handles.E6,'Visible')==0
    set(handles.E6,'Visible','on')
end
% hObject    handle to B5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in B7.
function B7_Callback(hObject, eventdata, handles)
syms x y z w;
if get(handles.E6,'Visible')==1
    A=str2sym(get(handles.E3,'String'));
    B=str2sym(get(handles.E4,'String'));
    C=str2sym(get(handles.E5,'String'));
    D=str2sym(get(handles.E6,'String'));
    ec=[A, B, C, D];
    vars=[x y z w];
    r=solve(ec,vars);
elseif get(handles.E5,'Visible')==1 && get(handles.E6,'Visible')==0
    A=str2sym(get(handles.E3,'String'));
    B=str2sym(get(handles.E4,'String'));
    C=str2sym(get(handles.E5,'String'));
    ec=[A, B, C];
    vars=[x y z];
    r=solve(ec,vars);
elseif get(handles.E5,'Visible')==0
    A=str2sym(get(handles.E3,'String'));
    B=str2sym(get(handles.E4,'String'));
    ec=[A, B];
    vars=[x y];
    r=solve(ec,vars);
end
if ~isempty(r)
    items = {'Soluciones:'};
    for i = 1:length(vars)  
        items{end+1} = sprintf('%s: %s', char(vars(i)), char(r.(char(vars(i)))));
    end
    set(handles.LB1, 'String', items);
else 
    set(handles.LB1, 'String', "No hay solución");
end
% hObject    handle to B7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function E3_Callback(hObject, eventdata, handles)
% hObject    handle to E3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E3 as text
%        str2double(get(hObject,'String')) returns contents of E3 as a double


% --- Executes during object creation, after setting all properties.
function E3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E4_Callback(hObject, eventdata, handles)
% hObject    handle to E4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E4 as text
%        str2double(get(hObject,'String')) returns contents of E4 as a double


% --- Executes during object creation, after setting all properties.
function E4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E5_Callback(hObject, eventdata, handles)
% hObject    handle to E5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E5 as text
%        str2double(get(hObject,'String')) returns contents of E5 as a double


% --- Executes during object creation, after setting all properties.
function E5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E6_Callback(hObject, eventdata, handles)
% hObject    handle to E6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E6 as text
%        str2double(get(hObject,'String')) returns contents of E6 as a double


% --- Executes during object creation, after setting all properties.
function E6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in PM2.
function PM2_Callback(hObject, eventdata, handles)
switch get(hObject,'Value')
    case 1
        set(handles.T5,'String',"Ecuación");
        set(handles.E10,'Visible','off');
        set(handles.E11,'Visible','off');
    case 2 
        set(handles.T5,'String',"a*x´(t)+b*x(t)+c==y(t)");
        set(handles.E10,'Visible','off');
        set(handles.E11,'Visible','off');
    case 3 
        set(handles.T5,'String',"a*x´´(t)+b*x´(t)+c*x(t)+d==y(t)");
        set(handles.E10,'Visible','on');
        set(handles.E11,'Visible','off');
    case 4 
       set(handles.T5,'String',"a*x´´´(t)+b*x´´(t)+c*x´(t)+d*x(t)+e==y(t)");
       set(handles.E10,'Visible','on');
       set(handles.E11,'Visible','on');
end
% hObject    handle to PM2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns PM2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from PM2


% --- Executes during object creation, after setting all properties.
function PM2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PM2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E7_Callback(hObject, eventdata, handles)
% hObject    handle to E7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E7 as text
%        str2double(get(hObject,'String')) returns contents of E7 as a double


% --- Executes during object creation, after setting all properties.
function E7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E8_Callback(hObject, eventdata, handles)
% hObject    handle to E8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E8 as text
%        str2double(get(hObject,'String')) returns contents of E8 as a double


% --- Executes during object creation, after setting all properties.
function E8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E9_Callback(hObject, eventdata, handles)
% hObject    handle to E9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E9 as text
%        str2double(get(hObject,'String')) returns contents of E9 as a double


% --- Executes during object creation, after setting all properties.
function E9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E12_Callback(hObject, eventdata, handles)
% hObject    handle to E12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E12 as text
%        str2double(get(hObject,'String')) returns contents of E12 as a double


% --- Executes during object creation, after setting all properties.
function E12_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E10_Callback(hObject, eventdata, handles)
% hObject    handle to E10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E10 as text
%        str2double(get(hObject,'String')) returns contents of E10 as a double


% --- Executes during object creation, after setting all properties.
function E10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function E11_Callback(hObject, eventdata, handles)
% hObject    handle to E11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of E11 as text
%        str2double(get(hObject,'String')) returns contents of E11 as a double


% --- Executes during object creation, after setting all properties.
function E11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to E11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in B8.
function B8_Callback(hObject, eventdata, handles)
syms y(t) x(t)
Dx=diff(x);
D2x=diff(x,2);
D3x=diff(x,3);
switch get(handles.PM2,'Value')
    case 1
        
    case 2 
        a=str2sym(get(handles.E7,'String'));
        b=str2sym(get(handles.E8,'String'));
        c=str2sym(get(handles.E9,'String'));
        y=str2sym(get(handles.E12,'String'));
        r=dsolve(a*Dx+b*x+c==y);
        set(handles.T5,'String',string(r))
        set(handles.T5,'BackgroundColor',[1 0 0])
    case 3 
       a=str2sym(get(handles.E7,'String'));
       b=str2sym(get(handles.E8,'String'));
       c=str2sym(get(handles.E9,'String'));
       d=str2sym(get(handles.E10,'String'));
       y=str2sym(get(handles.E12,'String'));
       r=dsolve(a*D2x+b*Dx+c*x+d==y);
       set(handles.T5,'String',string(r))
       set(handles.T5,'BackgroundColor',[1 0 0])
    case 4 
       a=str2sym(get(handles.E7,'String'));
       b=str2sym(get(handles.E8,'String'));
       c=str2sym(get(handles.E9,'String'));
       d=str2sym(get(handles.E10,'String'));
       e=str2sym(get(handles.E11,'String'));
       y=str2sym(get(handles.E12,'String'));
       r=dsolve(a*D3x+b*D2x+c*Dx+d*x+e==y);
       set(handles.T5,'String',string(r))
       set(handles.T5,'BackgroundColor',[1 0 0])
end
% hObject    handle to B8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in LB1.
function LB1_Callback(hObject, eventdata, handles)
% hObject    handle to LB1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns LB1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from LB1


% --- Executes during object creation, after setting all properties.
function LB1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to LB1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
