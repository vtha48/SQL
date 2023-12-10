--ĐỀ THI MẪU 1
Câu 1: Viết các trigger sau đây (giả thiết mỗi lần bổ sung hoặc cập nhật dữ liệu chỉ tác động trên
một dòng):
a. (1 điểm) Trigger trg_Registration_Insert bắt lệnh INSERT trên bảng Registration sao
cho mỗi khi bổ sung thêm một dòng dữ liệu trong bảng này thì cập nhật lại số lượng người đăng ký
dự thi chứng chỉ (cột NumberOfRegister) trong bảng Certificate.
b. (1,5 điểm) Trigger trg_Registration_Update bắt lệnh UPDATE trên bảng Registration
sao cho khi cập nhật giá trị cột ExamResult của một dòng trong bảng này thì đồng thời cập nhật lại
số lượng người đã thi đạt chứng chỉ (cột NumberOfPass) trong bảng Certificate.
Lưu ý: Kết quả thi chứng chỉ là đạt nếu điểm thi lớn hơn hoặc bằng 5.
Câu 2: Viết các thủ tục sau đây:
a. (1 điểm) proc_Registration_Add2
@ExamineeId int,
@CertificateId int,
@Result nvarchar(255) output
Có chức năng bổ sung một hồ sơ đăng ký dự thi chứng chỉ. Nếu bổ sung thành công, tham số
@Result trả về chuỗi rỗng, ngược lại tham số này trả về chuỗi cho biết lý do không bổ sung được
đăng ký.
b. (1 điểm) proc_SaveExamResult
@ExamineeId int,
@CertificateId int,
@ExamResult int,
@Result nvarchar(255) output
Có chức năng cập nhật điểm thi chứng chỉ. Trong đó lưu ý điểm thi phải là giá trị từ 0 đến 10. Nếu
cập nhật thành công, tham số @Result trả về chuỗi rỗng, ngược lại tham số này trả về chuỗi cho
biết lý do không cập nhật được điểm thi.
c. (1,5 điểm) proc_Examinee_Select
@SearchValue nvarchar(255) = N’’,
@Page int = 1,
@PageSize int = 20,
@RowCount int output,
@PageCount int output
Có chức năng tìm kiếm và hiển thị danh sách người dự thi dưới dạng phân trang dữ liệu. Trong đó,
@SearchValue là giá trị cần tìm (tìm kiếm tương đối theo họ tên, nếu tham số này là chuỗi rỗng thì
không tìm kiếm), @Page là trang cần hiển thị, @PageSize là số dòng dữ liệu được hiển thị trên mỗi
trang, tham số đầu ra @RowCount cho biết tổng số dòng dữ liệu và tham số đầu ra @PageCount cho
biết tổng số trang.
d. (1,5 điểm) proc_CountRegisteringByDate
@From date,
@To date
Có chức năng thống kê số lượng đăng ký dự thi của mỗi ngày trong khoảng thời gian từ ngày @From
đến ngày @To. Yêu cầu kết quả thống kê phải hiển thị đầy đủ tất cả các ngày trong khoảng thời gian
trên (những ngày không có người đăng ký dự thi thì hiển thị với số lượng là 0).
Câu 3: Viết các hàm sau đây
a. (1 điểm) func_CountPassed(@ExamineeId int) có chức năng tính số lượng chứng chỉ
mà người dự thi có mã @ExamineeId đã thi đạt.
b. (1,5 điểm) func_TotalByDate(@From date, @To date) có chức năng trả về bảng thống
kê số lượng đăng ký dự thi của mỗi ngày trong khoảng thời gian từ ngày @From đến ngày @To. Yêu
cầu kết quả thống kê phải hiển thị đầy đủ tất cả các ngày trong khoảng thời gian trên (những ngày
không có người đăng ký dự thi thì hiển thị với số lượng là 0)

--2d
if exists( select * from sys.objects where name = 'proc_CountRegisteringByDate_Draff')
	drop procedure  proc_CountRegisteringByDate_Draff;
go
create procedure  proc_CountRegisteringByDate_Draff
	@From date,
	@To date
as
begin
	set nocount on;

	declare @tbl table
	(
	RegisterTime date
	)
	declare @d date
	set @d = @From
	while (@d <= @To)
		begin
			insert into @tbl values (@d);
			set @d=dateadd(day,1,@d);
		end
	select t1.RegisterTime, isnull(t2.CountOfRegisterTime,0) as CountOfRegisterTime
	from @tbl as t1 
		left join
		(
		select RegisterTime, count(ExamineeId) as CountOfRegisterTime
		from Registration
		where RegisterTime between @From and @To
		group by RegisterTime
		) as t2 
		on t1.RegisterTime = t2.RegisterTime
end
go

--test case:
proc_CountRegisteringByDate_Draff
	@From ='2010/01/01',
	@To ='2023/02/02'


--3a Viết các hàm sau đây
a. (1 điểm) func_CountPassed(@ExamineeId int) có chức năng tính số lượng chứng chỉ
mà người dự thi có mã @ExamineeId đã thi đạt.

if exists(select * from sys.objects where name='func_CountPassed_Draff')
	drop function func_CountPassed_Draff;
go

create function func_CountPassed_Draff(@ExamineeId int)
returns int
as
begin
	-- Hàm k có cái này: set nocount on;
	declare @Count int;

	select @Count =count(*)
	from Registration 
	where ExamineeId= @ExamineeId and ExamResult>=5

	return @Count;
end
go

--test case:
select dbo.func_CountPassed_Draff(2)

--3b func_TotalByDate(@From date, @To date) có chức năng trả về bảng thống
kê số lượng đăng ký dự thi của mỗi ngày trong khoảng thời gian từ ngày @From đến ngày @To. Yêu
cầu kết quả thống kê phải hiển thị đầy đủ tất cả các ngày trong khoảng thời gian trên (những ngày
không có người đăng ký dự thi thì hiển thị với số lượng là 0)

if exists(select * from sys.objects where name='func_TotalByDate_Draff')
	drop function func_TotalByDate_Draff;
go

create function func_TotalByDate_Draff(@From date, @To date)
returns @tbl table
(
Ngay_Dang_Ky date,
So_Luong int
)
as
begin
	insert into @tbl(Ngay_Dang_Ky,So_luong)
		select RegisterTime, count(ExamineeId)
		from Registration
		where RegisterTime between @From and @To
		group by RegisterTime

	declare @d date
	set @d = @From;
	while(@d<=@To)
		begin
			if not exists( select * from  Registration where RegisterTime = @d)
				insert into @tbl(Ngay_Dang_Ky,So_luong) values(@d,0);
			set @d=dateadd(day,1,@d);
		end
	return;
end
go

--test case:
select * from dbo.func_TotalByDate_Draff('2020/02/02','2020/02/03')